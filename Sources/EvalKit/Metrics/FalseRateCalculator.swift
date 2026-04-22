// EvalKit — all processing is on-device. No data leaves the device.
//
// FalseRateCalculator.swift
// EvalKit/Metrics
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

/// Computes false-positive and false-negative counts and rates from a batch
/// of binary-classification `EvaluationResult` values.
///
/// Usage in a binary classification reporter:
/// ```swift
/// let fpfn = FalseRateCalculator.compute(
///     results: results,
///     positiveLabel: "spam",
///     negativeLabel: "not_spam"
/// )
/// ```
public enum FalseRateCalculator {

    // MARK: - Output

    /// Computed false-positive and false-negative metrics.
    public struct Output: Sendable {
        /// Number of cases where model predicted positive but actual was negative (FP).
        public let falsePositiveCount: Int
        /// Number of cases where model predicted negative but actual was positive (FN).
        public let falseNegativeCount: Int
        /// Number of true positives (predicted positive, actual positive).
        public let truePositiveCount: Int
        /// Number of true negatives (predicted negative, actual negative).
        public let trueNegativeCount: Int

        /// FP / (FP + TN). `0` when FP + TN == 0.
        public var falsePositiveRate: Double {
            let denom = falsePositiveCount + trueNegativeCount
            return denom > 0 ? Double(falsePositiveCount) / Double(denom) : 0.0
        }

        /// FN / (FN + TP). `0` when FN + TP == 0.
        public var falseNegativeRate: Double {
            let denom = falseNegativeCount + truePositiveCount
            return denom > 0 ? Double(falseNegativeCount) / Double(denom) : 0.0
        }
    }

    // MARK: - Compute (binary — explicit positive/negative label strings)

    /// Compute FP/FN metrics for a binary classification task.
    ///
    /// - Parameters:
    ///   - results: Raw `EvaluationResult` values from an `EvaluationRunner`.
    ///              `predictedLabel` and `expectedLabel` must be populated.
    ///   - positiveLabel: The label string that represents the **positive** class.
    ///   - negativeLabel: The label string that represents the **negative** class.
    /// - Returns: `Output` with FP/FN counts and rates.
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
    /// For each class `c`:
    ///   - FP(c) = cases where predicted == c but expected != c
    ///   - FN(c) = cases where expected == c but predicted != c
    ///   - TP(c) = cases where predicted == c and expected == c
    ///   - TN(c) = all other cases
    ///
    /// Totals are macro-summed across all classes.
    ///
    /// - Parameters:
    ///   - results: Raw results; `predictedLabel` and `expectedLabel` must be populated.
    ///   - labels: Complete ordered label vocabulary.
    /// - Returns: `Output` with summed FP/FN counts and aggregate rates.
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
