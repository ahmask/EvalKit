// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationReport.swift
// EvalKit/Models
//
// Final aggregated report produced by an EvaluationReporter.

import Foundation

/// The final output of a complete evaluation run.
///
/// ## Purpose
///
/// `EvaluationReport` is what you examine after an evaluation is done. It bundles
/// the computed aggregate metrics, all per-case raw results, a baseline pass/fail
/// verdict, and a timestamp. It is the single object you inspect in CI and the
/// evaluation UI — one `passedBaseline` check determines whether the feature
/// meets its quality bar.
///
/// ## When to use
///
/// You receive an `EvaluationReport` from any `EvaluationReporter.report(from:featureName:)`
/// call. Check `passedBaseline` to gate a CI build. Read `metrics` for aggregate numbers.
/// Iterate `results` to find specific failing cases by ID.
///
/// ## When not to use
///
/// Judge evaluation produces `JudgeReport` (EvalKitJudge) and rules evaluation
/// produces `RulesReport` (EvalKitRules). Both have the same conceptual shape but
/// carry different per-case result types.
///
/// ## Usage example
///
/// ```swift
/// let report = reporter.report(from: results, featureName: "RecipeClassifier")
///
/// // CI gate
/// guard report.passedBaseline else {
///     print("FAILED: \(report.baselineDescription ?? "")")
///     print("Accuracy: \(report.metrics.accuracy ?? 0)")
///     exit(1)
/// }
///
/// // Inspect failures
/// let failures = report.results.filter { !$0.isCorrect }
/// for f in failures {
///     print("[\(f.id)] predicted=\(f.predictedLabel ?? "-") expected=\(f.expectedLabel ?? "-")")
/// }
/// ```
public struct EvaluationReport: Sendable {

    /// Human-readable feature name used in reports and CI output.
    ///
    /// Choose a name that uniquely identifies the feature and model path, e.g.
    /// `"FeedbackClassification-CoreML"` or `"TopicFinder-LLM"`. This string
    /// appears in evaluation UIs and build logs.
    public let featureName: String

    /// Aggregated metrics for this run.
    ///
    /// Access fields like `metrics.accuracy`, `metrics.macroF1`, and
    /// `metrics.latencyMsP90`. Fields that are not applicable to this feature
    /// will be `nil`. Always check `metrics.errorCount` before drawing
    /// conclusions — errors silently exclude cases from metric calculations.
    public let metrics: EvaluationMetrics

    /// All per-case raw results from the evaluation batch.
    ///
    /// Iterate to find specific failing cases:
    /// `results.filter { !$0.isCorrect }`. Each result carries the case `id`,
    /// predicted and expected labels, latency, and any error message.
    public let results: [EvaluationResult]

    /// `true` when `metrics` meet or exceed the feature's defined baseline.
    ///
    /// Use this as the CI gate: fail the build or flag a regression when
    /// `passedBaseline` is `false`. The exact threshold that drives this value
    /// is described in `baselineDescription`.
    public let passedBaseline: Bool

    /// Human-readable description of the baseline requirement.
    ///
    /// Examples: `"accuracy >= 0.85"`, `"mean jaccard >= 0.75"`.
    /// `nil` if the reporter did not set one. Included in reports for human reviewers
    /// so they understand why a run passed or failed.
    public let baselineDescription: String?

    /// The timestamp when this report was generated.
    ///
    /// Use to correlate reports across evaluation runs and track metric trends over time.
    public let generatedAt: Date

    /// Number of test cases where `isCorrect == true`.
    ///
    /// Convenience computed from `results`. Equivalent to `Int(passRate * totalCases)`
    /// but derived directly from raw results rather than the rounded metric.
    public var passCount: Int {
        results.filter(\.isCorrect).count
    }

    // MARK: - Init

    public init(
        featureName: String,
        metrics: EvaluationMetrics,
        results: [EvaluationResult],
        passedBaseline: Bool,
        baselineDescription: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.featureName = featureName
        self.metrics = metrics
        self.results = results
        self.passedBaseline = passedBaseline
        self.baselineDescription = baselineDescription
        self.generatedAt = generatedAt
    }
}
