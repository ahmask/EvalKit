// EvalKit — all processing is on-device. No data leaves the device.
//
// RulesReport.swift
// EvalKitRules
//
// Final aggregated report from a rules evaluation run.

import Foundation

/// The final output of a `RulesReporter` run.
///
/// ## Purpose
///
/// `RulesReport` is the aggregated result of running a set of deterministic
/// `EvaluationRule` checks against a batch of test cases. It provides a pass rate,
/// a per-case result list, and a violation summary that shows which rules fired
/// most frequently across the batch.
///
/// ## When to use
///
/// You receive a `RulesReport` by `await`ing `RulesReporter.report(from:featureName:outputProvider:)`.
/// Use it to:
/// - Gate CI pipelines on `passedBaseline`
/// - Log per-case failures from `results`
/// - Find the most common violations from `violationSummary`
///
/// ## When not to use
///
/// `RulesReport` is for deterministic, rule-based checks only. For semantic quality
/// assessment (tone, groundedness, fluency), use `JudgeReport` (EvalKitJudge).
///
/// ## Usage example
///
/// ```swift
/// let report = await reporter.report(from: cases, featureName: "GreetingGeneration") { c in
///     try await session.respond(to: c.input).content
/// }
///
/// // CI gate
/// guard report.passedBaseline else { exit(1) }
///
/// // Most violated rule
/// if let top = report.violationSummary.max(by: { $0.value < $1.value }) {
///     print("Most violated rule: \(top.key) — \(top.value) cases")
/// }
/// ```
public struct RulesReport: Sendable {

    // MARK: - Properties

    /// The name of the feature or pipeline under evaluation.
    ///
    /// Used for display and logging. Matches the `featureName` argument passed to
    /// `RulesReporter.report(from:featureName:outputProvider:)`.
    public let featureName: String

    /// Per-case results for all evaluated test cases.
    ///
    /// One `RulesResult` per input case, in the order they completed (may differ from
    /// input order because cases are evaluated concurrently). Use `RulesResult.caseId`
    /// to correlate results back to input cases.
    public let results: [RulesResult]

    /// Fraction of cases where ALL configured rules passed. In `[0.0, 1.0]`.
    ///
    /// `1.0` = every case passed every rule. `0.0` = every case failed at least one rule.
    /// Compare against `minimumPassRate` to decide whether to ship a model version.
    public let passRate: Double

    /// `true` if `passRate` meets or exceeds the configured `minimumPassRate`.
    ///
    /// Use this as a binary gate in CI: `guard report.passedBaseline else { exit(1) }`.
    public let passedBaseline: Bool

    /// Human-readable description of the baseline requirement. `nil` if none was set.
    ///
    /// Example: `"pass rate >= 0.95"`. Included in the report for human-readable output.
    public let baselineDescription: String?

    /// Aggregated violation counts per rule name across all cases.
    ///
    /// Maps rule `name` to the number of cases that violated it. Only rules that
    /// were violated at least once appear in this dictionary. Use this to identify
    /// which rule is causing the most failures across the batch.
    public let violationSummary: [String: Int]

    /// The timestamp when this report was generated.
    ///
    /// Useful for versioning: store the report and compare pass rates across evaluation
    /// runs over time to detect regressions introduced by model updates.
    public let generatedAt: Date

    // MARK: - Init

    /// Create a rules report.
    ///
    /// - Parameters:
    ///   - featureName: Name of the feature under evaluation.
    ///   - results: Per-case rules results from `RulesReporter`.
    ///   - passRate: Fraction of cases that passed all rules.
    ///   - passedBaseline: Whether the pass rate met the minimum threshold.
    ///   - baselineDescription: Optional human-readable description of the requirement.
    ///   - violationSummary: Rule name → number of cases that violated the rule.
    ///   - generatedAt: Timestamp for the report. Defaults to `Date()`.
    public init(
        featureName: String,
        results: [RulesResult],
        passRate: Double,
        passedBaseline: Bool,
        baselineDescription: String? = nil,
        violationSummary: [String: Int],
        generatedAt: Date = Date()
    ) {
        self.featureName = featureName
        self.results = results
        self.passRate = passRate
        self.passedBaseline = passedBaseline
        self.baselineDescription = baselineDescription
        self.violationSummary = violationSummary
        self.generatedAt = generatedAt
    }
}
