// EvalKit — all processing is on-device. No data leaves the device.
//
// RulesResult.swift
// EvalKitRules
//
// Per-case result from a rules evaluation run.

import Foundation

/// The result of applying all configured rules to the output of a single test case.
///
/// ## Purpose
///
/// `RulesResult` is the per-case output of a `RulesReporter` run. It records whether
/// all rules passed for one test case, which rules were violated, and the latency for
/// generating the model output. `RulesReport.results` contains one `RulesResult` per
/// test case in the batch.
///
/// ## When to use
///
/// You receive `RulesResult` values by reading `RulesReport.results` after calling
/// `RulesReporter.report(from:featureName:outputProvider:)`. Inspect individual
/// results to find which specific test cases violated which rules.
///
/// ## Usage example
///
/// ```swift
/// let report = await reporter.report(from: cases, featureName: "GreetingGeneration") { c in
///     try await session.respond(to: c.input).content
/// }
///
/// // Find all cases that failed the language rule
/// let languageFailures = report.results.filter { result in
///     result.violations.contains { $0.ruleName == "language_match" }
/// }
/// for failure in languageFailures {
///     print("[\(failure.caseId)] violations: \(failure.violations.map(\.failureMessage))")
/// }
/// ```
public struct RulesResult: Sendable {

    // MARK: - Properties

    /// Stable identifier matching the originating `TextEvaluationCase.id`.
    ///
    /// Use this to correlate a failed result back to its source test case for debugging.
    public let caseId: String

    /// `true` if every configured rule passed for this case.
    ///
    /// When `passed == false`, at least one rule was violated. Inspect `violations`
    /// for the full list. When `passed == true`, `violations` is empty.
    public let passed: Bool

    /// The list of rule violations for this case. Empty when `passed == true`.
    ///
    /// Each entry names the violated rule and provides a human-readable failure message
    /// describing what was wrong with the output. Multiple rules can fire for a single case.
    public let violations: [RuleViolation]

    /// End-to-end latency for this case in milliseconds.
    ///
    /// Includes the time spent calling `outputProvider` to generate the model's output.
    /// Does not include rule evaluation time (rules are deterministic and near-instantaneous).
    /// Use `RulesReport.results.map(\.latencyMs)` with `P90Calculator` to compute
    /// latency statistics across the batch.
    public let latencyMs: Double

    // MARK: - Computed

    /// Number of rule violations for this case.
    ///
    /// `0` when `passed == true`. Equivalent to `violations.count`.
    /// A case with multiple violations failed multiple rules simultaneously.
    public var violationCount: Int { violations.count }

    // MARK: - Init

    /// Create a rules result.
    ///
    /// - Parameters:
    ///   - caseId: Stable test-case identifier.
    ///   - passed: Whether all rules passed.
    ///   - violations: The list of rule violations (empty if passed).
    ///   - latencyMs: End-to-end latency in milliseconds.
    public init(caseId: String, passed: Bool, violations: [RuleViolation], latencyMs: Double) {
        self.caseId = caseId
        self.passed = passed
        self.violations = violations
        self.latencyMs = latencyMs
    }
}
