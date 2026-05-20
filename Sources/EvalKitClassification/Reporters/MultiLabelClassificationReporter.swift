// EvalKit — all processing is on-device. No data leaves the device.
//
// MultiLabelClassificationReporter.swift
// EvalKitClassification/Reporters
//
// EvaluationReporter for multi-label classification tasks where a single input
// can have multiple correct labels simultaneously (e.g. image tagging).

import Foundation
import EvalKit

/// A ready-to-use `EvaluationReporter` for multi-label classification tasks.
///
/// ## Purpose
///
/// Some classification features assign multiple labels to a single input simultaneously.
/// `MultiLabelClassificationReporter` evaluates these by treating each label as an
/// independent binary classification problem, then aggregating with micro and macro F1.
/// Standard single-label metrics (accuracy, confusion matrix) are not meaningful here
/// because there is no single "correct" label to compare against.
///
/// ## When to use
///
/// Use `MultiLabelClassificationReporter` when a single input can have **zero or more**
/// correct labels at the same time:
/// - Image tagging: a photo tagged as both `"beach"` and `"sunset"`.
/// - Multi-topic retrieval: a query that belongs to both `"flights"` and `"booking"`.
/// - Content filtering: a message that violates both `"spam"` and `"offensive"` rules.
///
/// ## When not to use
///
/// - **Exactly one label per input**: Use `StandardClassificationReporter` instead.
///   Multi-label metrics are not meaningful when each example has a single ground truth.
/// - **Free-form generation**: Use `LLMJudgeReporter` (EvalKitJudge). When there is
///   no fixed label vocabulary, precision/recall/F1 are not applicable.
///
/// ## How predicted and expected labels are read
///
/// The reporter reads `EvaluationResult.predictedLabel` and `expectedLabel` as
/// comma-separated label lists (e.g. `"beach,sunset"` and `"beach,sunset,travel"`).
/// Your runner must serialise the model's multi-label output into this format.
///
/// ## Usage example
///
/// ```swift
/// // Runner — serialises the model's multi-label output as comma-separated string
/// let runner = SimilarityRunner(primaryMetric: .jaccard()) { input in
///     let tags = try await tagModel.predict(input)
///     return tags.joined(separator: ",")
/// }
///
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// // Reporter
/// let reporter = MultiLabelClassificationReporter(
///     labels: ["beach", "sunset", "travel", "food"],
///     minimumF1: 0.80
/// )
/// let report = reporter.report(from: results, featureName: "ImageTagging")
///
/// print(report.passedBaseline)        // true / false
/// print(report.metrics.macroF1!)      // macro-averaged F1, e.g. 0.82
/// print(report.metrics.weightedF1!)   // micro-averaged F1, e.g. 0.85
/// ```
public struct MultiLabelClassificationReporter: EvaluationReporter, Sendable {

    // MARK: - Properties

    /// The complete ordered label vocabulary.
    ///
    /// Every label that can appear in `predictedLabel` or `expectedLabel` must be
    /// listed here. Labels not in this array are silently ignored during metric
    /// computation. Order does not affect metric values.
    public let labels: [String]

    /// Minimum macro-averaged F1 required for `passedBaseline` to be `true`.
    ///
    /// Macro F1 averages the per-label F1 equally across all labels, giving equal
    /// weight to rare labels. When macro F1 falls below this threshold,
    /// `report.passedBaseline` is `false`. Defaults to `0.80` (80%).
    public let minimumF1: Double

    // MARK: - Init

    /// Create a multi-label classification reporter.
    ///
    /// - Parameters:
    ///   - labels: All possible label strings. These are matched against comma-separated
    ///     values in `predictedLabel` and `expectedLabel`. Whitespace around each label
    ///     is trimmed automatically.
    ///   - minimumF1: Macro-averaged F1 threshold below which `passedBaseline` is `false`.
    ///     Defaults to `0.80`. Set to `1.0` to require perfect multi-label F1 in CI.
    public init(labels: [String], minimumF1: Double = 0.80) {
        self.labels = labels
        self.minimumF1 = minimumF1
    }

    // MARK: - EvaluationReporter

    /// Build a full evaluation report from a batch of raw multi-label classification results.
    ///
    /// Parses comma-separated predicted and expected label strings, computes per-label
    /// precision/recall/F1, and derives micro and macro averages.
    ///
    /// - Macro F1 (`metrics.macroF1`) averages per-label F1 equally — good when all labels matter equally.
    /// - Micro F1 (`metrics.weightedF1`) treats every label instance equally across the dataset —
    ///   dominated by frequent labels.
    ///
    /// `passedBaseline` is `true` when macro F1 meets or exceeds `minimumF1`.
    ///
    /// - Parameters:
    ///   - results: Per-case results from your runner. `predictedLabel` and `expectedLabel`
    ///     must be comma-separated label strings. Results where both are `nil` contribute
    ///     to `errorCount` but are excluded from F1 calculations.
    ///   - featureName: Human-readable feature name used in the report.
    /// - Returns: A complete `EvaluationReport` with macro and micro F1 in `metrics`.
    public func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
        // Per-label TP, FP, FN counts
        var tpMap: [String: Int] = [:]
        var fpMap: [String: Int] = [:]
        var fnMap: [String: Int] = [:]

        for label in labels {
            tpMap[label] = 0
            fpMap[label] = 0
            fnMap[label] = 0
        }

        for result in results {
            let predicted = Set(
                (result.predictedLabel ?? "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
            let expected = Set(
                (result.expectedLabel ?? "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )

            for label in labels {
                let isPredicted = predicted.contains(label)
                let isExpected  = expected.contains(label)
                switch (isPredicted, isExpected) {
                case (true,  true):  tpMap[label, default: 0] += 1
                case (true,  false): fpMap[label, default: 0] += 1
                case (false, true):  fnMap[label, default: 0] += 1
                case (false, false): break
                }
            }
        }

        // Per-label P, R, F1
        var perLabelF1: [Double] = []
        var microTP = 0, microFP = 0, microFN = 0

        for label in labels {
            let tp = tpMap[label, default: 0]
            let fp = fpMap[label, default: 0]
            let fn = fnMap[label, default: 0]
            microTP += tp; microFP += fp; microFN += fn

            let precision = (tp + fp) > 0 ? Double(tp) / Double(tp + fp) : 0.0
            let recall    = (tp + fn) > 0 ? Double(tp) / Double(tp + fn) : 0.0
            let f1        = (precision + recall) > 0
                ? 2 * precision * recall / (precision + recall)
                : 0.0
            perLabelF1.append(f1)
        }

        // Macro F1
        let macroF1 = labels.isEmpty ? 0.0 : perLabelF1.reduce(0, +) / Double(labels.count)

        // Micro F1
        let microPrecision = (microTP + microFP) > 0
            ? Double(microTP) / Double(microTP + microFP) : 0.0
        let microRecall = (microTP + microFN) > 0
            ? Double(microTP) / Double(microTP + microFN) : 0.0
        let microF1 = (microPrecision + microRecall) > 0
            ? 2 * microPrecision * microRecall / (microPrecision + microRecall)
            : 0.0

        let latencies = results.map(\.latencyMs)
        let passRate = results.isEmpty ? 0.0 : Double(results.filter(\.isCorrect).count) / Double(results.count)

        let metrics = EvaluationMetrics(
            totalCases:     results.count,
            passRate:       passRate,
            errorCount:     results.filter { $0.error != nil }.count,
            macroF1:        macroF1,
            weightedF1:     microF1,
            latencyMsMean:  P90Calculator.mean(latencies),
            latencyMsP90:   P90Calculator.p90(latencies)
        )

        return EvaluationReport(
            featureName:         featureName,
            metrics:             metrics,
            results:             results,
            passedBaseline:      macroF1 >= minimumF1,
            baselineDescription: "macroF1 >= \(minimumF1)"
        )
    }
}
