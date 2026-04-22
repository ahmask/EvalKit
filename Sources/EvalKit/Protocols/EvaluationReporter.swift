// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationReporter.swift
// EvalKit/Protocols
//
// Protocol for aggregating raw EvaluationResults into a final EvaluationReport.

import Foundation

/// Aggregates raw `EvaluationResult` values into a structured `EvaluationReport`.
///
/// Implement `report(from:featureName:)` to compute the metrics relevant to your
/// feature and determine whether the evaluation passes the baseline.
///
/// Example:
/// ```swift
/// struct FeedbackReporter: EvaluationReporter {
///     let baseline: Double = 0.85  // minimum acceptable accuracy
///     func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
///         let metrics = PrecisionRecallF1.compute(from: results, labels: HelpCategory.allLabels)
///         let passed = (metrics.accuracy ?? 0) >= baseline
///         return EvaluationReport(
///             featureName: featureName,
///             metrics: metrics, results: results,
///             passedBaseline: passed,
///             baselineDescription: "accuracy >= \(baseline)"
///         )
///     }
/// }
/// ```
public protocol EvaluationReporter: Sendable {
    /// Build a full evaluation report from a batch of raw results.
    func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport
}
