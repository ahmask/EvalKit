// EvalKit — all processing is on-device. No data leaves the device.
//
// PrecisionRecallF1.swift
// EvalKitClassification/Metrics
//
// Computes per-class and aggregate precision, recall, and F1 from EvaluationResults.

import Foundation
import EvalKit

/// Computes per-class and aggregate precision, recall, and F1 from a batch of `EvaluationResult` values.
///
/// ## Purpose
///
/// Accuracy alone is a misleading metric for imbalanced classification datasets.
/// `PrecisionRecallF1` computes the full set of classification quality metrics —
/// per-class precision, recall, and F1, plus macro and weighted averages, accuracy,
/// and a confusion matrix — from one call. `StandardClassificationReporter` uses
/// this internally, but you can also call it directly to build a custom reporter
/// with feature-specific baseline logic.
///
/// ## When to use
///
/// Call `PrecisionRecallF1.compute(from:labels:)` when:
/// - You are writing a custom `EvaluationReporter` that needs P/R/F1 metrics.
/// - You need the per-class breakdown (`classMetrics`) to debug which labels
///   the model handles poorly.
/// - You need the confusion matrix to identify systematic misclassifications
///   between specific class pairs.
///
/// For the common case (classify text into N labels, gate on minimum accuracy),
/// use `StandardClassificationReporter` directly — it calls this internally.
///
/// ## When not to use
///
/// - If each example can have multiple correct labels simultaneously, use
///   `MultiLabelClassificationReporter` instead. That reporter treats each label
///   as an independent binary classification problem.
/// - If your feature generates free-form text with no single correct answer, use
///   `LLMJudgeReporter` (EvalKitJudge) — precision and recall are not meaningful
///   for open-ended generation tasks.
///
/// ## Usage example
///
/// ```swift
/// let output = PrecisionRecallF1.compute(
///     from: results,
///     labels: FeedbackCategory.allCases.map(\.rawValue)
/// )
///
/// // Aggregate quality
/// print("Accuracy:", output.accuracy)    // e.g. 0.847
/// print("Macro F1:", output.macroF1)     // e.g. 0.844
///
/// // Per-class breakdown — find the weakest label
/// for cls in output.classMetrics.sorted(by: { $0.f1 < $1.f1 }) {
///     print("\(cls.label): P=\(cls.precision) R=\(cls.recall) F1=\(cls.f1)")
/// }
///
/// // Confusion matrix — find systematic misclassifications
/// let matrix = output.confusionMatrix
/// let confused = matrix.count(expected: "baggage", predicted: "seating")
/// print("baggage predicted as seating: \(confused) times")
/// ```
///
/// All computation is pure and on-device. No data is printed or logged.
public enum PrecisionRecallF1 {

    // MARK: - Per-class metrics

    /// Intermediate per-class breakdown for a single label.
    ///
    /// Produced for every label in the vocabulary by `compute(from:labels:)`.
    /// Use the `classMetrics` array on `Output` to inspect which labels are
    /// performing well and which need more training data or label cleanup.
    public struct ClassMetrics: Sendable {

        /// The label this entry describes (e.g. `"baggage"`, `"seating"`).
        public let label: String

        /// Number of cases correctly predicted as this label (TP).
        ///
        /// The diagonal value for this class in the confusion matrix.
        /// A low TP alongside a high `support` indicates the model rarely predicts this class correctly.
        public let truePositives: Int

        /// Number of cases incorrectly predicted as this label when the truth was something else (FP).
        ///
        /// High FP means the model over-predicts this class — it assigns this label to examples
        /// that belong to other classes. This reduces `precision`.
        public let falsePositives: Int

        /// Number of cases with this label that were predicted as something else (FN).
        ///
        /// High FN means the model under-predicts this class — it misses examples that should
        /// have been assigned this label. This reduces `recall`.
        public let falseNegatives: Int

        /// Number of ground-truth examples with this label in the evaluation dataset.
        ///
        /// Also called "support". Used to compute weighted averages. A class with low support
        /// (few examples) has unreliable P/R/F1 estimates — collect more test data for it.
        public let support: Int

        /// TP / (TP + FP). `0` when TP + FP == 0 (model never predicted this label).
        ///
        /// - `1.0` = every time the model predicted this label, it was correct.
        /// - `0.0` = every prediction of this label was wrong.
        ///
        /// Low precision means the model is over-triggering on this label.
        public var precision: Double {
            let d = truePositives + falsePositives
            return d > 0 ? Double(truePositives) / Double(d) : 0.0
        }

        /// TP / (TP + FN). `0` when TP + FN == 0 (no examples of this label in the dataset).
        ///
        /// - `1.0` = every example with this label was correctly identified.
        /// - `0.0` = the model missed every example of this label.
        ///
        /// Low recall means the model under-triggers on this label — it misses too many positives.
        public var recall: Double {
            let d = truePositives + falseNegatives
            return d > 0 ? Double(truePositives) / Double(d) : 0.0
        }

        /// Harmonic mean of precision and recall. `0` when both precision and recall are 0.
        ///
        /// - `1.0` = perfect precision and recall for this class.
        /// - `0.0` = the model either never predicts this class or always gets it wrong.
        ///
        /// F1 is the single best summary metric for a class because it penalises both
        /// over-prediction (low precision) and under-prediction (low recall) equally.
        public var f1: Double {
            let p = precision, r = recall
            let d = p + r
            return d > 0 ? 2 * p * r / d : 0.0
        }
    }

    // MARK: - Full output

    /// Result struct holding per-class breakdown, aggregate scalars, and a confusion matrix.
    public struct Output: Sendable {

        /// Overall fraction of correctly classified examples, in `[0.0, 1.0]`.
        ///
        /// - `1.0` = every prediction was correct.
        /// - `0.0` = every prediction was wrong.
        ///
        /// Accuracy is the primary CI gate metric. For imbalanced datasets, also inspect
        /// `macroF1` — a high accuracy with low macroF1 means the model is good at common
        /// classes but ignores rare ones.
        public let accuracy: Double

        /// Per-class precision, recall, and F1 for every label in the vocabulary.
        ///
        /// Sorted in the same order as the `labels` array passed to `compute(from:labels:)`.
        /// Sort by `f1` ascending to find the weakest labels, or by `support` to understand
        /// which classes are represented most strongly in your dataset.
        public let classMetrics: [ClassMetrics]

        /// Unweighted mean of per-class precision values, in `[0.0, 1.0]`.
        ///
        /// - `1.0` = no false positives for any class.
        /// - `0.0` = all predictions for every class were wrong.
        ///
        /// Use macro metrics when all classes matter equally regardless of how often they appear.
        /// If common classes should dominate the metric, use `weightedPrecision` instead.
        public let macroPrecision: Double

        /// Unweighted mean of per-class recall values, in `[0.0, 1.0]`.
        ///
        /// - `1.0` = no missed examples for any class.
        /// - `0.0` = every positive example was missed.
        ///
        /// Use macro recall when catching every class's positives matters equally,
        /// regardless of class frequency. Prioritise when false negatives are costly.
        public let macroRecall: Double

        /// Unweighted mean of per-class F1 scores, in `[0.0, 1.0]`.
        ///
        /// - `1.0` = perfect precision and recall across all classes.
        /// - `0.0` = no class was correctly predicted at all.
        ///
        /// Use `macroF1` as your primary quality metric when classes are imbalanced —
        /// it gives equal weight to rare classes. Use `weightedF1` when frequent classes
        /// should count more toward the overall score.
        public let macroF1: Double

        /// Support-weighted mean of per-class precision values, in `[0.0, 1.0]`.
        ///
        /// Dominated by the most common classes. Use when frequent classes should
        /// contribute more to the overall precision signal.
        public let weightedPrecision: Double

        /// Support-weighted mean of per-class recall values, in `[0.0, 1.0]`.
        ///
        /// Dominated by the most common classes. A large gap between `macroRecall`
        /// and `weightedRecall` means rare classes are performing very differently
        /// from frequent ones.
        public let weightedRecall: Double

        /// Support-weighted mean of per-class F1 scores, in `[0.0, 1.0]`.
        ///
        /// The most commonly cited F1 in imbalanced datasets because frequent classes
        /// dominate. Compare against `macroF1` — a large gap signals the model performs
        /// well on common classes but fails on rare ones.
        public let weightedF1: Double

        /// Full confusion matrix. Row = expected label, column = predicted label.
        ///
        /// Use to identify which class pairs the model systematically confuses.
        /// See `ConfusionMatrix.count(expected:predicted:)` for targeted lookups.
        public let confusionMatrix: ConfusionMatrix
    }

    // MARK: - Compute

    /// Compute classification metrics from a batch of results.
    ///
    /// Computes accuracy, per-class TP/FP/FN/support, macro and weighted P/R/F1,
    /// and builds the full confusion matrix in a single pass over `results`.
    ///
    /// - Parameters:
    ///   - results: Raw results from an `EvaluationRunner`. Only results where both
    ///     `predictedLabel` and `expectedLabel` are non-nil are included in the per-class
    ///     counts. Results with `nil` labels are excluded from confusion matrix construction
    ///     but still count toward `totalCases` in `EvaluationMetrics`.
    ///   - labels: The complete ordered label vocabulary — all possible class strings.
    ///     Must include every label that appears in either `predictedLabel` or `expectedLabel`.
    ///     Labels not in this array are silently excluded from per-class and confusion matrix
    ///     calculations. A common mistake is omitting labels that exist in the test data but
    ///     were never predicted — those still need to be in this array to appear in the output.
    /// - Returns: `Output` with accuracy, per-class `classMetrics`, macro/weighted P/R/F1,
    ///   and the full `confusionMatrix`. All values are `0.0` when `results` is empty.
    public static func compute(from results: [EvaluationResult], labels: [String]) -> Output {
        guard !labels.isEmpty else {
            return Output(
                accuracy: 0.0,
                classMetrics: [],
                macroPrecision: 0.0,
                macroRecall: 0.0,
                macroF1: 0.0,
                weightedPrecision: 0.0,
                weightedRecall: 0.0,
                weightedF1: 0.0,
                confusionMatrix: ConfusionMatrix(labels: [], matrix: [])
            )
        }

        let total = results.count
        let correct = results.filter(\.isCorrect).count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0.0

        let classMetrics: [ClassMetrics] = labels.map { label in
            let support = results.filter { $0.expectedLabel == label }.count
            let tp = results.filter { $0.expectedLabel == label && $0.predictedLabel == label }.count
            let fp = results.filter { $0.expectedLabel != label && $0.predictedLabel == label }.count
            let fn = results.filter { $0.expectedLabel == label && $0.predictedLabel != label }.count
            return ClassMetrics(
                label: label,
                truePositives: tp,
                falsePositives: fp,
                falseNegatives: fn,
                support: support
            )
        }

        let n = Double(labels.count)
        let macroPrecision = classMetrics.map(\.precision).reduce(0, +) / n
        let macroRecall    = classMetrics.map(\.recall).reduce(0, +) / n
        let macroF1        = classMetrics.map(\.f1).reduce(0, +) / n

        let totalSupport = classMetrics.map(\.support).reduce(0, +)
        let (wp, wr, wf): (Double, Double, Double)
        if totalSupport > 0 {
            let w = Double(totalSupport)
            wp = classMetrics.map { Double($0.support) * $0.precision }.reduce(0, +) / w
            wr = classMetrics.map { Double($0.support) * $0.recall    }.reduce(0, +) / w
            wf = classMetrics.map { Double($0.support) * $0.f1        }.reduce(0, +) / w
        } else {
            (wp, wr, wf) = (0, 0, 0)
        }

        // Build confusion matrix: matrix[i][j] = count(expected==labels[i] && predicted==labels[j])
        let labelIndex: [String: Int] = Dictionary(
            uniqueKeysWithValues: labels.enumerated().map { ($1, $0) }
        )
        var matrix = Array(repeating: Array(repeating: 0, count: labels.count), count: labels.count)
        for result in results {
            guard let expected = result.expectedLabel,
                  let predicted = result.predictedLabel,
                  let row = labelIndex[expected],
                  let col = labelIndex[predicted] else { continue }
            matrix[row][col] += 1
        }
        let confusionMatrix = ConfusionMatrix(labels: labels, matrix: matrix)

        return Output(
            accuracy: accuracy,
            classMetrics: classMetrics,
            macroPrecision: macroPrecision,
            macroRecall: macroRecall,
            macroF1: macroF1,
            weightedPrecision: wp,
            weightedRecall: wr,
            weightedF1: wf,
            confusionMatrix: confusionMatrix
        )
    }
}
