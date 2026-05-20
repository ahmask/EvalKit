// EvalKit — all processing is on-device. No data leaves the device.
//
// FalseRateCalculator.swift
// EvalKitClassification/Metrics
//
// Computes false-positive and false-negative counts and rates from a batch
// of EvaluationResults. Relevant for binary classification and object detection.
//
// Definitions (standard ML conventions):
//   FalsePositive (FP): model predicted Positive but actual was Negative
//   FalseNegative (FN): model predicted Negative but actual was Positive
//   FalsePositiveRate (FPR) = FP / (FP + TN)   — also called "fall-out"
//   FalseNegativeRate (FNR) = FN / (FN + TP)   — also called "miss rate"

import Foundation
import EvalKit

/// Computes false-positive and false-negative counts and rates from a batch
/// of `EvaluationResult` values.
///
/// ## When to use this instead of `StandardClassificationReporter`
///
/// `StandardClassificationReporter` gates on overall accuracy. Use
/// `FalseRateCalculator` when **what kind of error** matters more than the
/// overall error count — for example:
///
/// - **Spam / content filtering** — a false negative (missed spam) may be
///   more costly than a false positive (blocking a legit message).
/// - **Fraud / safety classifiers** — a false negative (missed fraud) is
///   catastrophic; you want `falseNegativeRate` below a hard threshold.
/// - **Medical or risk triage** — regulators require explicit FNR / FPR bounds.
/// - **Object detection** — miss rate and fall-out are standard reporting metrics.
///
/// ## Where it fits in the EvalKit workflow
///
/// Call it on the same `[EvaluationResult]` array produced by your
/// `EvaluationRunner` — either instead of or alongside a reporter:
///
/// ```swift
/// // Binary classification (two explicit label strings)
/// let fpfn = FalseRateCalculator.compute(
///     results: results,
///     positiveLabel: "spam",
///     negativeLabel: "not_spam"
/// )
/// guard fpfn.falseNegativeRate < 0.05 else {
///     print("Miss rate too high: \(fpfn.falseNegativeRate)")
/// }
///
/// // Multi-class (pass the full label vocabulary)
/// let fpfn = FalseRateCalculator.compute(
///     results: results,
///     labels: MyCategory.allCases.map(\.rawValue)
/// )
/// print("Aggregate FPR: \(fpfn.falsePositiveRate)")
/// ```
///
/// Both overloads return the same `Output` type. `Output.falsePositiveRate`
/// is FP / (FP + TN); `Output.falseNegativeRate` is FN / (FN + TP).
public enum FalseRateCalculator {

    // MARK: - Output

    /// Computed false-positive and false-negative metrics for a batch of results.
    public struct Output: Sendable {

        /// Number of cases where the model predicted positive but the actual label was negative (FP).
        ///
        /// In spam filtering: legitimate emails incorrectly marked as spam.
        /// In fraud detection: legitimate transactions incorrectly flagged.
        /// A high FP count damages user trust by creating false alarms.
        public let falsePositiveCount: Int

        /// Number of cases where the model predicted negative but the actual label was positive (FN).
        ///
        /// In spam filtering: spam emails that reached the inbox.
        /// In fraud detection: fraudulent transactions that were not flagged.
        /// A high FN count means the model is missing real positives — often the more dangerous error.
        public let falseNegativeCount: Int

        /// Number of cases correctly predicted as positive (predicted positive, actual positive).
        ///
        /// Used as the denominator of `falseNegativeRate`. A high TP count alongside
        /// a low FN count means the model reliably catches positive examples.
        public let truePositiveCount: Int

        /// Number of cases correctly predicted as negative (predicted negative, actual negative).
        ///
        /// Used as the denominator of `falsePositiveRate`. A high TN count alongside
        /// a low FP count means the model rarely raises false alarms.
        public let trueNegativeCount: Int

        /// FP / (FP + TN) — the false-positive rate. `0` when FP + TN == 0.
        ///
        /// Also called "fall-out". Answers: "Of all the actual negatives, what fraction
        /// did the model incorrectly flag as positive?"
        ///
        /// - `0.0` = no false alarms — the model never misclassifies a negative as positive.
        /// - `1.0` = every negative was incorrectly flagged as positive.
        ///
        /// Returns `0` when `falsePositiveCount + trueNegativeCount == 0` (no negatives in the batch).
        public var falsePositiveRate: Double {
            let denom = falsePositiveCount + trueNegativeCount
            return denom > 0 ? Double(falsePositiveCount) / Double(denom) : 0.0
        }

        /// FN / (FN + TP) — the false-negative rate. `0` when FN + TP == 0.
        ///
        /// Also called "miss rate". Answers: "Of all the actual positives, what fraction
        /// did the model fail to detect?"
        ///
        /// - `0.0` = no misses — the model detected every positive.
        /// - `1.0` = every positive was missed.
        ///
        /// This is the critical metric for safety, fraud, and medical triage features
        /// where missing a positive is more costly than a false alarm.
        /// Returns `0` when `falseNegativeCount + truePositiveCount == 0` (no positives in the batch).
        public var falseNegativeRate: Double {
            let denom = falseNegativeCount + truePositiveCount
            return denom > 0 ? Double(falseNegativeCount) / Double(denom) : 0.0
        }
    }

    // MARK: - Compute (binary — explicit positive/negative label strings)

    /// Compute FP/FN metrics for a binary classification task.
    ///
    /// Use this overload when your task has exactly two classes with clear positive and
    /// negative semantics — spam vs not_spam, fraud vs legitimate, positive vs negative sentiment.
    ///
    /// - Parameters:
    ///   - results: Raw `EvaluationResult` values from an `EvaluationRunner`.
    ///     Both `predictedLabel` and `expectedLabel` must be populated. Results where
    ///     either field is `nil` are silently skipped.
    ///   - positiveLabel: The label string that represents the **positive** class
    ///     (e.g. `"spam"`, `"fraud"`, `"positive"`). Any result with this expected
    ///     label is counted as a positive example.
    ///   - negativeLabel: The label string that represents the **negative** class
    ///     (e.g. `"not_spam"`, `"legitimate"`, `"negative"`). Provided for symmetry;
    ///     the implementation uses `positiveLabel` to classify all four cells.
    /// - Returns: `Output` with FP/FN/TP/TN counts and computed FPR/FNR rates.
    ///
    /// - Note: Results whose labels match neither `positiveLabel` nor `negativeLabel`
    ///   are still classified: any label that is not `positiveLabel` is treated as
    ///   negative. Ensure your dataset contains only the two expected labels.
    public static func compute(
        results: [EvaluationResult],
        positiveLabel: String,
        negativeLabel: String
    ) -> Output {
        var fp = 0, fn = 0, tp = 0, tn = 0

        for result in results {
            guard let predicted = result.predictedLabel,
                  let expected  = result.expectedLabel else { continue }

            let predictedPos = predicted == positiveLabel
            let actualPos    = expected  == positiveLabel

            switch (predictedPos, actualPos) {
            case (true,  true):  tp += 1  // True Positive
            case (true,  false): fp += 1  // False Positive
            case (false, true):  fn += 1  // False Negative
            case (false, false): tn += 1  // True Negative
            }
        }

        return Output(
            falsePositiveCount: fp,
            falseNegativeCount: fn,
            truePositiveCount:  tp,
            trueNegativeCount:  tn
        )
    }

    // MARK: - Compute (multi-class — aggregated across all classes)

    /// Compute aggregate FP/FN metrics over a multi-class classification batch.
    ///
    /// For each class `c`, the binary confusion cells are derived by treating that
    /// class as "positive" and all others as "negative":
    ///   - TP(c) = predicted == c AND expected == c
    ///   - FP(c) = predicted == c AND expected != c
    ///   - FN(c) = expected == c AND predicted != c
    ///   - TN(c) = all other cases
    ///
    /// The counts are then macro-summed across all classes into a single `Output`.
    ///
    /// - Parameters:
    ///   - results: Raw results; `predictedLabel` and `expectedLabel` must be populated.
    ///     Results where either field is `nil` are silently skipped.
    ///   - labels: The complete ordered label vocabulary. Every label in your evaluation
    ///     dataset must appear here. Labels not in this array are not counted in any cell.
    /// - Returns: `Output` with summed FP/FN/TP/TN counts and aggregate FPR/FNR rates.
    ///
    /// - Note: The multi-class FPR and FNR computed here are macro-aggregates across all
    ///   classes — they are not equivalent to the standard binary FPR/FNR. Use the binary
    ///   overload when your task is genuinely binary. Use this overload only when you need
    ///   a single aggregate miss-rate signal across a multi-class problem.
    public static func compute(
        results: [EvaluationResult],
        labels: [String]
    ) -> Output {
        var totalFP = 0, totalFN = 0, totalTP = 0, totalTN = 0

        for label in labels {
            var fp = 0, fn = 0, tp = 0, tn = 0
            for result in results {
                guard let predicted = result.predictedLabel,
                      let expected  = result.expectedLabel else { continue }

                let predictedPos = predicted == label
                let actualPos    = expected  == label

                switch (predictedPos, actualPos) {
                case (true,  true):  tp += 1
                case (true,  false): fp += 1
                case (false, true):  fn += 1
                case (false, false): tn += 1
                }
            }
            totalFP += fp
            totalFN += fn
            totalTP += tp
            totalTN += tn
        }

        return Output(
            falsePositiveCount: totalFP,
            falseNegativeCount: totalFN,
            truePositiveCount:  totalTP,
            trueNegativeCount:  totalTN
        )
    }
}
