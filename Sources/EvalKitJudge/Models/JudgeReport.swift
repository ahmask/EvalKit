// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeReport.swift
// EvalKitJudge/Models
//
// Final aggregated report produced by an LLMJudgeReporter run.

import Foundation

/// The final output of an `LLMJudgeReporter` run.
///
/// ## Purpose
///
/// `JudgeReport` is the aggregated result of evaluating a batch of test cases across
/// one or more judge dimensions. It provides overall pass rate, per-dimension breakdowns,
/// raw per-case results, and a baseline gate for CI integration.
///
/// ## When to use
///
/// You receive a `JudgeReport` by `await`ing
/// `LLMJudgeReporter.report(from:featureName:outputProvider:keyFactsProvider:)`.
/// Use it to:
/// - Gate CI on `passedBaseline`
/// - Compare per-dimension quality across model versions via `metrics.dimensionMetrics`
/// - Inspect individual failing cases from `results`
///
/// ## Usage example
///
/// ```swift
/// let reporter = LLMJudgeReporter(runner: runner, minimumPassRate: 0.9)
/// let report = await reporter.report(from: cases, featureName: "PassengerGreeting") { c in
///     try await session.respond(to: c.input).content
/// }
///
/// guard report.passedBaseline else { exit(1) }  // CI gate
///
/// // Per-dimension breakdown
/// for dim in report.metrics.dimensionMetrics {
///     print("\(dim.dimension): avg=\(dim.averageScore), passRate=\(dim.passRate)")
/// }
///
/// // Failures
/// for result in report.results.filter({ !$0.allPassed }) {
///     print("[\(result.caseId)]", result.scores.filter { !$0.passed }.map(\.dimension))
/// }
/// ```
public struct JudgeReport: Sendable {

    // MARK: - Properties

    /// The name of the feature or pipeline under evaluation.
    ///
    /// Matches the `featureName` argument passed to `LLMJudgeReporter.report(...)`.
    /// Used for display and logging.
    public let featureName: String

    /// Aggregated metrics computed across all evaluated cases and all dimensions.
    ///
    /// Contains overall pass rate, latency statistics, and per-dimension `DimensionMetrics`.
    /// This is the primary entry point for comparing quality across model versions.
    public let metrics: JudgeMetrics

    /// Raw per-case judge results, one per evaluated test case.
    ///
    /// May not be in the same order as the input cases — cases are evaluated concurrently.
    /// Use `JudgeResult.caseId` to correlate results back to input cases.
    public let results: [JudgeResult]

    /// `true` if the overall pass rate met or exceeded the configured `minimumPassRate`.
    ///
    /// Use as a binary gate in CI: `guard report.passedBaseline else { exit(1) }`.
    /// The overall pass rate is `metrics.passRate`.
    public let passedBaseline: Bool

    /// Human-readable description of the baseline requirement. `nil` if none was set.
    ///
    /// Example: `"pass rate >= 0.90"`. Included in the report for logging and human review.
    public let baselineDescription: String?

    /// The timestamp when this report was generated.
    ///
    /// Store this timestamp alongside the report to track quality trends over time and
    /// correlate changes in pass rates with model version updates.
    public let generatedAt: Date

    // MARK: - Init

    /// Create a judge report.
    ///
    /// - Parameters:
    ///   - featureName: Name of the feature under evaluation.
    ///   - metrics: Aggregated metrics for this run from `JudgeMetrics.compute(from:...)`.
    ///   - results: Raw per-case `JudgeResult` values.
    ///   - passedBaseline: Whether the overall pass rate met the minimum threshold.
    ///   - baselineDescription: Optional human-readable description of the requirement.
    ///   - generatedAt: Timestamp for the report. Defaults to `Date()`.
    public init(
        featureName: String,
        metrics: JudgeMetrics,
        results: [JudgeResult],
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
