// EvalKit — all processing is on-device. No data leaves the device.
//
// StandardClassificationReporter.swift
// EvalKitClassification/Reporters
//
// Ready-to-use EvaluationReporter for multi-class text classification.
// Computes accuracy, macro/weighted P/R/F1, latency mean and P90,
// and compares accuracy against a configurable minimum threshold.

import Foundation
import EvalKit

/// A ready-to-use `EvaluationReporter` for multi-class text classification tasks.
///
/// ## Purpose
///
/// `StandardClassificationReporter` is the default reporter for any feature that
/// classifies text into one of N fixed labels. It handles the full reporting pipeline:
/// compute accuracy, macro and weighted P/R/F1, latency mean and P90, and gate on
/// a minimum accuracy threshold — all in one call.
///
/// ## When to use
///
/// Use `StandardClassificationReporter` when:
/// - Your feature assigns each input exactly one label from a fixed vocabulary
///   (e.g. feedback categorisation, intent detection, language detection).
/// - You want to gate on minimum accuracy in CI.
/// - You need macro and weighted F1 in the report without writing custom aggregation.
///
/// ## When not to use
///
/// - **Multiple labels per example**: If a single input can have more than one correct
///   label simultaneously (e.g. image tagging, multi-topic retrieval), use
///   `MultiLabelClassificationReporter` instead.
/// - **No single correct answer**: If your feature generates free-form text (greetings,
///   summaries, RAG responses) where any well-written output is acceptable, use
///   `LLMJudgeReporter` (EvalKitJudge).
/// - **Gate on FPR/FNR, not accuracy**: If you need to control the false-negative rate
///   (e.g. safety or fraud classifiers), write a custom reporter using `FalseRateCalculator`
///   to compute and gate on the miss rate directly.
///
/// ## Usage example
///
/// ```swift
/// // 1. Build your dataset and runner
/// let cases = dataset.map { TextEvaluationCase(id: $0.id, input: $0.text, expectedOutput: $0.label) }
/// let runner = CoreMLLatencyRunner { text in
///     try myRecipeModel.prediction(text: text).label
/// }
///
/// // 2. Collect results
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// // 3. Report
/// let reporter = StandardClassificationReporter(
///     labels: RecipeCategory.allCases.map(\.rawValue),
///     minimumAccuracy: 0.85
/// )
/// let report = reporter.report(from: results, featureName: "RecipeClassifier")
///
/// print(report.passedBaseline)          // true / false
/// print(report.metrics.accuracy ?? 0)  // e.g. 0.847
/// print(report.metrics.macroF1 ?? 0)   // e.g. 0.844
/// print(report.metrics.latencyMsP90)   // e.g. 120.3 ms
/// ```
///
/// If you need to track hallucinations or custom metrics, write a feature-specific
/// `EvaluationReporter` instead and use `PrecisionRecallF1.compute()` directly.
public struct StandardClassificationReporter: EvaluationReporter {

    // MARK: - Properties

    /// The complete ordered label vocabulary. Must cover all possible labels in your dataset.
    ///
    /// Pass every label that can appear in `EvaluationResult.predictedLabel` or
    /// `EvaluationResult.expectedLabel`. Labels not in this array are silently excluded
    /// from per-class metrics and the confusion matrix. A common mistake is omitting
    /// labels that exist in the test data but were never predicted by the model.
    public let labels: [String]

    /// Minimum accuracy required for the report to pass the baseline gate.
    ///
    /// When `metrics.accuracy >= minimumAccuracy`, `report.passedBaseline` is `true`.
    /// When accuracy falls below this threshold, `passedBaseline` is `false` and CI
    /// should flag a regression. Defaults to `0.85` (85%).
    public let minimumAccuracy: Double

    // MARK: - Init

    /// Create a reporter for a classification feature.
    ///
    /// - Parameters:
    ///   - labels: All possible label strings (e.g. `MyCategory.allCases.map(\.rawValue)`).
    ///     The order does not affect aggregate metrics but determines column order in the
    ///     confusion matrix produced by `PrecisionRecallF1`.
    ///   - minimumAccuracy: Accuracy threshold below which `report.passedBaseline` is `false`.
    ///     Defaults to `0.85`. Set to `1.0` to require perfect accuracy in CI.
    public init(labels: [String], minimumAccuracy: Double = 0.85) {
        self.labels = labels
        self.minimumAccuracy = minimumAccuracy
    }

    // MARK: - EvaluationReporter

    /// Build a full evaluation report from a batch of raw classification results.
    ///
    /// Computes accuracy, macro/weighted precision/recall/F1, latency mean and P90,
    /// and sets `passedBaseline` when `accuracy >= minimumAccuracy`.
    ///
    /// - Parameters:
    ///   - results: All per-case results from your classification runner.
    ///   - featureName: Human-readable name used in the report header and CI output.
    /// - Returns: A complete `EvaluationReport`. Results with `nil` labels are counted
    ///   in `totalCases` and `errorCount` but are excluded from classification metrics.
    public func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
        let prf      = PrecisionRecallF1.compute(from: results, labels: labels)
        let latencies = results.map(\.latencyMs)

        let metrics = EvaluationMetrics(
            totalCases:        results.count,
            passRate:          prf.accuracy,
            errorCount:        results.filter { $0.error != nil }.count,
            accuracy:          prf.accuracy,
            macroPrecision:    prf.macroPrecision,
            macroRecall:       prf.macroRecall,
            macroF1:           prf.macroF1,
            weightedPrecision: prf.weightedPrecision,
            weightedRecall:    prf.weightedRecall,
            weightedF1:        prf.weightedF1,
            latencyMsMean:     P90Calculator.mean(latencies),
            latencyMsP90:      P90Calculator.p90(latencies)
        )

        return EvaluationReport(
            featureName:         featureName,
            metrics:             metrics,
            results:             results,
            passedBaseline:      prf.accuracy >= minimumAccuracy,
            baselineDescription: "accuracy >= \(minimumAccuracy)"
        )
    }
}
