// EvalKit — all processing is on-device. No data leaves the device.
//
// LLMJudgeReporter.swift
// EvalKitJudge/Reporters
//
// Orchestrates an LLM-as-a-Judge evaluation run over a batch of TextEvaluationCases.

import Foundation
import EvalKit

/// Orchestrates an LLM-as-a-Judge evaluation run over a batch of `TextEvaluationCase` values.
///
/// ## Purpose
///
/// `LLMJudgeReporter` is the top-level harness for judge-based evaluation. It runs all
/// test cases concurrently (using `TaskGroup`), calls `LLMJudgeRunner` to score each
/// case across all configured dimensions, aggregates the results into `JudgeMetrics`,
/// and produces a `JudgeReport` with a CI-ready pass/fail baseline gate.
///
/// ## When to use
///
/// Use `LLMJudgeReporter` to evaluate any feature where output quality cannot be checked
/// deterministically — greeting tone, RAG answer groundedness, summarisation recall,
/// safety screening, coherence, and fluency.
///
/// ## When not to use
///
/// - **Deterministic checks** (word count, JSON format, vocabulary): Use `RulesReporter`
///   (EvalKitRules). Rules are faster, cheaper, and more reliable for properties that code
///   can verify without a second LLM call.
/// - **Classification accuracy**: Use `StandardClassificationReporter` or
///   `MultiLabelClassificationReporter` (EvalKitClassification).
///
/// ## Usage example
///
/// ```swift
/// let reporter = LLMJudgeReporter(
///     dimensions: [.fluency(language: "de"), .tone(), .safety()],
///     minimumPassRate: 0.90,
///     passingThreshold: 3.0,
///     language: "de"
/// ) { prompt in
///     try await judgeSession.respond(to: prompt).content
/// }
///
/// let report = await reporter.report(from: cases, featureName: "PassengerGreeting") { testCase in
///     try await generatorSession.respond(to: testCase.input).content
/// } keyFactsProvider: { testCase in
///     // Optional: provide per-case facts for groundedness/recall dimensions
///     return ["recall": testCase.expectedOutput.components(separatedBy: ",")]
/// }
///
/// guard report.passedBaseline else { exit(1) }
///
/// for dim in report.metrics.dimensionMetrics {
///     print("\(dim.dimension): avg=\(dim.averageScore), passRate=\(dim.passRate)")
/// }
/// ```
public struct LLMJudgeReporter: Sendable {

    // MARK: - Properties

    private let dimensions: [JudgeDimension]
    private let minimumPassRate: Double
    private let passingThreshold: Double
    private let itemByItemPassingThreshold: Double
    private let language: String?
    private let judge: @Sendable (String) async throws -> String

    // MARK: - Init

    /// Create an LLM judge reporter.
    ///
    /// - Parameters:
    ///   - dimensions: Quality dimensions to evaluate per test case. Defaults to all seven
    ///     built-in dimensions (fluency, groundedness, recall, tone, safety, coherence,
    ///     faithfulness). Each dimension adds one judge LLM call per case — choose only
    ///     the dimensions relevant to your feature.
    ///   - minimumPassRate: Fraction of cases (in `[0.0, 1.0]`) that must have
    ///     `JudgeResult.allPassed == true` for `report.passedBaseline` to be `true`.
    ///     Default `0.80`. Set higher (e.g. `0.95`) for features with strict quality bars.
    ///   - passingThreshold: Raw holistic score `[1.0, 5.0]` at or above which a holistic
    ///     dimension is considered passing. Default `3.0`. Increase for stricter requirements.
    ///   - itemByItemPassingThreshold: Ratio `[0.0, 1.0]` at or above which an item-by-item
    ///     dimension (groundedness, recall) is considered passing. Default `0.75`.
    ///   - language: Optional BCP-47 language tag passed to `LLMJudgeRunner`. Affects only the
    ///     fluency dimension. Pass the user's language when evaluating multilingual features.
    ///   - judge: Closure that sends a prompt string to the on-device judge LLM and returns
    ///     its raw response. Must return valid JSON in the format expected by the dimension's
    ///     scoring pattern. Errors from this closure are captured in `JudgeResult.error`.
    public init(
        dimensions: [JudgeDimension] = [
            .fluency(), .groundedness(), .recall(), .tone(), .safety(), .coherence(), .faithfulness()
        ],
        minimumPassRate: Double = 0.80,
        passingThreshold: Double = 3.0,
        itemByItemPassingThreshold: Double = 0.75,
        language: String? = nil,
        judge: @escaping @Sendable (String) async throws -> String
    ) {
        self.dimensions = dimensions
        self.minimumPassRate = minimumPassRate
        self.passingThreshold = passingThreshold
        self.itemByItemPassingThreshold = itemByItemPassingThreshold
        self.language = language
        self.judge = judge
    }

    // MARK: - Reporting

    /// Run judge evaluation over a batch of test cases and return a `JudgeReport`.
    ///
    /// All cases are evaluated concurrently (using `TaskGroup`). For each case, the
    /// `outputProvider` is called first to generate the model's output, then all
    /// configured dimensions are scored sequentially via `LLMJudgeRunner`. If
    /// `outputProvider` throws, the case is recorded with an error and no scores —
    /// the batch continues with remaining cases.
    ///
    /// - Parameters:
    ///   - cases: The test cases to evaluate. Each case is processed as a concurrent task.
    ///   - featureName: Human-readable feature name written into the report.
    ///   - outputProvider: Closure called once per case to generate the model's response.
    ///     Call your generative model here. Errors are captured automatically.
    ///   - keyFactsProvider: Optional closure returning per-case key-facts overrides —
    ///     a dictionary mapping dimension name to a list of facts to verify for that case.
    ///     Pass `nil` (default) to use each dimension's built-in default facts. Required
    ///     for dimensions like groundedness and recall where the facts vary per test case.
    ///
    ///   **Common mistake**: passing `nil` for `keyFactsProvider` when using groundedness
    ///   or recall dimensions. Those dimensions have empty default `keyFacts` arrays — without
    ///   a `keyFactsProvider`, the judge receives no facts to verify and scores will be `1.0`
    ///   (vacuously — zero facts found, zero expected).
    ///
    /// - Returns: A `JudgeReport` with `metrics`, `results`, `passedBaseline`, and metadata.
    public func report(
        from cases: [TextEvaluationCase],
        featureName: String,
        outputProvider: @escaping @Sendable (TextEvaluationCase) async throws -> String,
        keyFactsProvider: (@Sendable (TextEvaluationCase) -> [String: [String]])? = nil
    ) async -> JudgeReport {
        let runner = LLMJudgeRunner(
            dimensions: dimensions,
            passingThreshold: passingThreshold,
            itemByItemPassingThreshold: itemByItemPassingThreshold,
            language: language,
            judge: judge
        )

        var results: [JudgeResult] = []

        await withTaskGroup(of: JudgeResult.self) { group in
            for testCase in cases {
                group.addTask {
                    let start = Date()
                    let output: String
                    do {
                        output = try await outputProvider(testCase)
                    } catch {
                        let latencyMs = Date().timeIntervalSince(start) * 1000
                        return JudgeResult(
                            caseId: testCase.id,
                            scores: [],
                            latencyMs: latencyMs,
                            error: error.localizedDescription
                        )
                    }

                    let keyFactsOverride = keyFactsProvider?(testCase) ?? [:]
                    return await runner.evaluate(
                        caseId: testCase.id,
                        input: testCase.input,
                        output: output,
                        keyFactsOverride: keyFactsOverride
                    )
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        let metrics = JudgeMetrics.compute(
            from: results,
            passingThreshold: passingThreshold,
            itemByItemPassingThreshold: itemByItemPassingThreshold
        )

        let passedBaseline = metrics.passRate >= minimumPassRate

        return JudgeReport(
            featureName: featureName,
            metrics: metrics,
            results: results,
            passedBaseline: passedBaseline
        )
    }
}
