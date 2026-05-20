// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationReporter.swift
// EvalKit/Protocols
//
// Protocol for aggregating raw EvaluationResults into a final EvaluationReport.

import Foundation

/// Aggregates raw `EvaluationResult` values into a structured `EvaluationReport`.
///
/// ## Purpose
///
/// After your runner produces one `EvaluationResult` per test case, a reporter
/// converts the entire batch into a single `EvaluationReport` with aggregate
/// metrics and a pass/fail baseline gate. The reporter is the layer that decides
/// *what success means* for your feature — which metrics matter, and at what
/// threshold the feature has regressed.
///
/// ## When to use
///
/// Implement a custom `EvaluationReporter` when:
/// - The built-in reporters (`StandardClassificationReporter`, `RetrievalReporter`)
///   do not cover your metric needs.
/// - You need to combine multiple metric types (e.g. accuracy + hallucination rate).
/// - You need a custom baseline condition beyond a single threshold.
///
/// For most standard features, use a built-in reporter instead of writing your own.
///
/// ## When not to use
///
/// - For text classification, use `StandardClassificationReporter` or
///   `MultiLabelClassificationReporter` (EvalKitClassification) directly.
/// - For retrieval and similarity, use `RetrievalReporter` (EvalKitRetrieval).
/// - For rules-based evaluation, use `RulesReporter` (EvalKitRules).
/// - For LLM quality evaluation, use `LLMJudgeReporter` (EvalKitJudge).
///
/// ## Usage example
///
/// ```swift
/// // Custom reporter that gates on both accuracy and hallucination rate
/// struct FeedbackReporter: EvaluationReporter {
///     let labels: [String]
///     let minimumAccuracy: Double = 0.85
///     let maximumHallucinationRate: Double = 0.02
///
///     func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
///         let prf = PrecisionRecallF1.compute(from: results, labels: labels)
///         let hallucinations = results.filter(\.hallucinationFlag).count
///         let hallucinationRate = results.isEmpty ? 0.0
///             : Double(hallucinations) / Double(results.count)
///
///         let passed = prf.accuracy >= minimumAccuracy
///             && hallucinationRate <= maximumHallucinationRate
///
///         let metrics = EvaluationMetrics(
///             totalCases: results.count,
///             passRate: prf.accuracy,
///             errorCount: results.filter { $0.error != nil }.count,
///             accuracy: prf.accuracy,
///             latencyMsMean: P90Calculator.mean(results.map(\.latencyMs)),
///             latencyMsP90: P90Calculator.p90(results.map(\.latencyMs)),
///             hallucinationCount: hallucinations,
///             hallucinationRate: hallucinationRate
///         )
///         return EvaluationReport(
///             featureName: featureName,
///             metrics: metrics,
///             results: results,
///             passedBaseline: passed,
///             baselineDescription: "accuracy >= \(minimumAccuracy) && hallucinationRate <= \(maximumHallucinationRate)"
///         )
///     }
/// }
/// ```
public protocol EvaluationReporter: Sendable {

    /// Build a full evaluation report from a batch of raw results.
    ///
    /// Compute all metrics relevant to your feature, set `passedBaseline` based on
    /// your feature's threshold, and return an `EvaluationReport`.
    ///
    /// - Parameters:
    ///   - results: All per-case results produced by your `EvaluationRunner`. The
    ///     order matches the order in which you called `runner.run`.
    ///   - featureName: Human-readable name for the report header and CI output
    ///     (e.g. `"FeedbackClassification-CoreML"`).
    /// - Returns: A complete `EvaluationReport` with aggregated metrics, all raw
    ///   results, a baseline verdict, and a timestamp.
    ///
    /// - Note: A common mistake is populating only the metrics your reporter reads
    ///   while leaving all other fields `nil`. Always populate at minimum `totalCases`,
    ///   `passRate`, `errorCount`, `latencyMsMean`, and `latencyMsP90`.
    func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport
}
