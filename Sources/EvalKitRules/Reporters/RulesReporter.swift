// EvalKit — all processing is on-device. No data leaves the device.
//
// RulesReporter.swift
// EvalKitRules/Reporters
//
// Orchestrates a rules-based evaluation run over a batch of TextEvaluationCases.

import Foundation
import EvalKit

/// Orchestrates a rules-based evaluation run over a batch of `TextEvaluationCase` values.
///
/// ## Purpose
///
/// `RulesReporter` runs every configured `EvaluationRule` against each test case's model
/// output and produces a `RulesReport` with per-case violations, an aggregate pass rate,
/// and a baseline gate. All cases are evaluated **concurrently** using `TaskGroup`, so
/// latency measurements reflect real-world inference time per case.
///
/// Use `RulesReporter` as the evaluation harness whenever you need deterministic output
/// quality checks — length, format, vocabulary, regex, language — across a large test set.
///
/// ## When to use
///
/// - You need to verify that every model output satisfies hard constraints (e.g. max word
///   count, valid JSON, approved vocabulary) across a regression suite.
/// - You want to gate CI on a pass rate threshold (e.g. 95% of outputs must pass all rules).
/// - You need a violation summary to identify which rule is causing the most failures.
///
/// ## When not to use
///
/// - **Semantic quality checks** (fluency, tone, groundedness): Use `LLMJudgeReporter`
///   (EvalKitJudge). Rules cannot catch things that require judgment.
/// - **Classification accuracy**: Use `StandardClassificationReporter` or
///   `MultiLabelClassificationReporter` (EvalKitClassification). Those reporters compute
///   precision/recall/F1 for label prediction tasks; rules are for free-form output checks.
///
/// ## Usage example
///
/// ```swift
/// let reporter = RulesReporter(
///     rules: [MaxSentencesRule(maximum: 1), LanguageMatchRule(expectedLanguage: "de")],
///     minimumPassRate: 1.0   // all cases must pass all rules
/// )
///
/// let report = await reporter.report(from: cases, featureName: "GreetingGeneration") { testCase in
///     try await session.respond(to: testCase.input).content
/// }
///
/// guard report.passedBaseline else { exit(1) }  // CI gate
///
/// // Diagnose failures
/// print(report.violationSummary)        // ["max_sentences": 2, "language_match": 1]
/// for result in report.results.filter({ !$0.passed }) {
///     print("[\(result.caseId)]", result.violations.map(\.failureMessage))
/// }
/// ```
public struct RulesReporter: Sendable {

    // MARK: - Properties

    /// The rules applied to every test case's output.
    ///
    /// Each rule is evaluated independently for every case. A case fails if ANY rule
    /// returns `false`. Pass multiple rules to enforce multiple constraints simultaneously.
    /// Rules are evaluated in order within a case, but cases are evaluated concurrently.
    private let rules: [any EvaluationRule]

    /// Minimum fraction of cases that must pass all rules for `passedBaseline` to be `true`.
    ///
    /// `1.0` = every case must pass every rule (strictest setting — use for hard safety checks).
    /// `0.95` = up to 5% of cases may fail (use when occasional edge-case failures are acceptable).
    /// `0.0` = baseline always passes regardless of violations (useful for informational runs).
    private let minimumPassRate: Double

    // MARK: - Init

    /// Create a rules reporter.
    ///
    /// - Parameters:
    ///   - rules: The rules to apply to every test case's output. Evaluated for each case
    ///     in order; the first violation does NOT short-circuit remaining rule checks —
    ///     all rules are always evaluated so the full violation list is captured.
    ///   - minimumPassRate: Fraction of cases that must pass all rules for `passedBaseline`
    ///     to be `true`. Defaults to `1.0` (every case must pass every rule).
    public init(rules: [any EvaluationRule], minimumPassRate: Double = 1.0) {
        self.rules = rules
        self.minimumPassRate = minimumPassRate
    }

    // MARK: - Reporting

    /// Run rules evaluation over a batch of test cases and return a `RulesReport`.
    ///
    /// Calls `outputProvider` for every case concurrently, then evaluates all rules
    /// against each output. If `outputProvider` throws for a case, the case is recorded
    /// as failed with a synthetic `"output_provider"` violation — it does NOT abort
    /// the entire batch.
    ///
    /// - Parameters:
    ///   - cases: The test cases to evaluate. Each case is processed as a concurrent task.
    ///   - featureName: Human-readable feature name written into the report.
    ///   - outputProvider: Closure called once per case with the `TextEvaluationCase`.
    ///     Call your model here and return its raw string output. Errors are captured
    ///     automatically — do not catch them inside the closure unless you want to
    ///     return a fallback string instead of recording a failure.
    /// - Returns: A `RulesReport` with per-case `RulesResult` values, a `passRate`,
    ///   a `violationSummary` dictionary, and `passedBaseline`.
    public func report(
        from cases: [TextEvaluationCase],
        featureName: String,
        outputProvider: @escaping @Sendable (TextEvaluationCase) async throws -> String
    ) async -> RulesReport {
        var results: [RulesResult] = []

        await withTaskGroup(of: RulesResult.self) { group in
            for testCase in cases {
                group.addTask {
                    let start = Date()
                    let output: String
                    do {
                        output = try await outputProvider(testCase)
                    } catch {
                        let latencyMs = Date().timeIntervalSince(start) * 1000
                        let errorViolation = RuleViolation(
                            ruleName: "output_provider",
                            failureMessage: "outputProvider threw: \(error.localizedDescription)",
                            output: ""
                        )
                        return RulesResult(
                            caseId: testCase.id,
                            passed: false,
                            violations: [errorViolation],
                            latencyMs: latencyMs
                        )
                    }

                    let latencyMs = Date().timeIntervalSince(start) * 1000
                    var violations: [RuleViolation] = []

                    for rule in self.rules {
                        if !rule.evaluate(output: output, context: [:]) {
                            violations.append(RuleViolation(
                                ruleName: rule.name,
                                failureMessage: rule.failureDescription(for: output, context: [:]),
                                output: output
                            ))
                        }
                    }

                    return RulesResult(
                        caseId: testCase.id,
                        passed: violations.isEmpty,
                        violations: violations,
                        latencyMs: latencyMs
                    )
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        let total = results.count
        let passed = results.filter(\.passed).count
        let passRate = total > 0 ? Double(passed) / Double(total) : 0.0

        // Aggregate violation counts per rule
        var violationSummary: [String: Int] = [:]
        for result in results {
            for violation in result.violations {
                violationSummary[violation.ruleName, default: 0] += 1
            }
        }

        return RulesReport(
            featureName: featureName,
            results: results,
            passRate: passRate,
            passedBaseline: passRate >= minimumPassRate,
            baselineDescription: "pass rate >= \(minimumPassRate)",
            violationSummary: violationSummary
        )
    }
}
