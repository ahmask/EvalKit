// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelsJudgeReporter.swift
// EvalKitFoundationModels
//
// Zero-config LLM-as-judge reporter using Apple FoundationModels.

import Foundation
import EvalKit
import EvalKitJudge

/// The primary entry point for LLM-as-judge evaluation using Apple FoundationModels.
/// Zero session management required — import the module and evaluate.
///
/// ## What is this?
///
/// `FoundationModelsJudgeReporter` orchestrates an LLM-as-judge evaluation run over a
/// batch of test cases using Apple's on-device FoundationModels. It creates and manages
/// a dedicated judge `LanguageModelSession` internally — separate from your generation
/// session — so you never write session management code for evaluation.
///
/// Internally it delegates to `LLMJudgeRunner` for per-dimension scoring and produces
/// the same `JudgeReport` you would get from `LLMJudgeReporter`.
///
/// ## Why does it exist?
///
/// `LLMJudgeReporter` in `EvalKitJudge` requires the developer to manage a
/// `LanguageModelSession` and wire it into a judge closure. This type removes that
/// requirement entirely for developers evaluating on-device FoundationModels features.
/// The judge session is an implementation detail of EvalKit, not something you should
/// have to think about.
///
/// ## When to use it
///
/// - You are evaluating a FoundationModels feature on a real device with Apple Intelligence
/// - You want zero boilerplate — no session creation, no availability checks in your code
/// - Your app targets iOS 26.0+ or macOS 26.0+
///
/// ## When NOT to use it
///
/// - **Testing on simulator** → use `LLMJudgeReporter` with a mock closure
/// - **Running on macOS without Apple Intelligence** → use `LLMJudgeReporter` with a custom session
/// - **Using a custom or fine-tuned model** → use `LLMJudgeReporter` with your own closure
/// - **Your deployment target is below iOS 26.0** → use `LLMJudgeReporter`
///
/// ## Complete usage example
///
/// ```swift
/// import EvalKitFoundationModels
/// import FoundationModels
///
/// // Your existing generation session — you own this
/// let generationSession = LanguageModelSession(
///     instructions: "You are a personalised greeting generator for an airline app."
/// )
///
/// // Create the reporter — no session management needed for the judge
/// let reporter = FoundationModelsJudgeReporter(
///     dimensions: [.fluency(language: "en"), .groundedness(), .tone()],
///     minimumPassRate: 0.80,
///     judgeInstructions: "You are an expert evaluator for airline customer communications."
/// )
///
/// // Define test cases
/// let cases = [
///     TextEvaluationCase(id: "cancel-1",
///         input: "Flight LH400 cancelled. HON Circle member.",
///         expectedOutput: ""),
///     TextEvaluationCase(id: "gate-1",
///         input: "Gate changed to B22. Senator member.",
///         expectedOutput: ""),
/// ]
///
/// // Run evaluation — outputProvider calls YOUR existing feature
/// let report = await reporter.report(
///     from: cases,
///     featureName: "PassengerGreeting",
///     outputProvider: { testCase in
///         // Use your existing generation session here
///         let response = try await generationSession.respond(to: testCase.input)
///         return response.content
///     },
///     keyFactsProvider: { testCase in
///         // Optional: provide facts for groundedness / recall checking
///         if testCase.id == "cancel-1" {
///             return ["groundedness": ["LH400 is mentioned", "cancellation is mentioned"]]
///         }
///         return [:]
///     }
/// )
///
/// // Read results
/// print(report.passedBaseline)        // true / false — use as XCTest assertion or CI gate
/// print(report.metrics.passRate)      // e.g. 0.87
///
/// for dim in report.metrics.dimensionMetrics {
///     print("\(dim.dimension): avg=\(dim.averageScore) passRate=\(dim.passRate)")
/// }
/// ```
///
/// ## Note on session separation
///
/// `FoundationModelsJudgeReporter` creates a dedicated judge session internally,
/// separate from your generation session. This is intentional — the judge session
/// uses different system instructions optimised for evaluation, not generation.
/// Both sessions run on-device. No data leaves the device.
public struct FoundationModelsJudgeReporter: Sendable {

    // MARK: - Properties

    private let dimensions: [JudgeDimension]
    private let minimumPassRate: Double
    private let passingThreshold: Double
    private let itemByItemPassingThreshold: Double
    private let language: String?
    private let judge: @Sendable (String) async throws -> String

    // MARK: - Public Init

    /// Create a reporter that uses Apple FoundationModels as the judge.
    ///
    /// The reporter creates and manages a `LanguageModelSession` internally.
    /// You do not need to create or manage any session for the judge.
    ///
    /// - Parameters:
    ///   - dimensions: Quality dimensions to evaluate per test case. Defaults to the six
    ///     built-in dimensions: `.fluency()`, `.tone()`, `.safety()`, `.coherence()`,
    ///     `.groundedness()`, `.recall()`. Each dimension adds one judge LLM call per case —
    ///     choose only the dimensions relevant to your feature.
    ///   - minimumPassRate: Fraction of cases `[0.0, 1.0]` that must have
    ///     `JudgeResult.allPassed == true` for `report.passedBaseline` to be `true`.
    ///     Default `0.80`. Increase to `0.95` for features with strict quality bars.
    ///   - passingThreshold: Raw holistic score `[1.0, 5.0]` at or above which a holistic
    ///     dimension (tone, safety, coherence) is considered passing. Default `3.0`.
    ///   - itemByItemPassingThreshold: Ratio `[0.0, 1.0]` at or above which an item-by-item
    ///     dimension (groundedness, recall) is considered passing. Default `0.75` (75% of
    ///     facts must be present or grounded).
    ///   - language: Optional BCP-47 language tag (e.g. `"de"`, `"fr"`) passed to the
    ///     fluency dimension. Pass the user's language when evaluating multilingual features.
    ///     Ignored by all non-fluency dimensions.
    ///   - judgeInstructions: Optional system instructions for the internal judge session.
    ///     Use to specialise the judge's evaluation stance for your domain — for example:
    ///     `"You are an expert evaluator for airline customer communications."`.
    ///     When `nil`, the judge session uses no system instructions.
    @available(iOS 26.0, macOS 26.0, *)
    public init(
        dimensions: [JudgeDimension] = [
            .fluency(), .tone(), .safety(), .coherence(), .groundedness(), .recall()
        ],
        minimumPassRate: Double = 0.80,
        passingThreshold: Double = 3.0,
        itemByItemPassingThreshold: Double = 0.75,
        language: String? = nil,
        judgeInstructions: String? = nil
    ) {
        let adapter = FoundationModelsAdapter(judgeInstructions: judgeInstructions)
        self.judge = { prompt in try await adapter.respond(to: prompt) }
        self.dimensions = dimensions
        self.minimumPassRate = minimumPassRate
        self.passingThreshold = passingThreshold
        self.itemByItemPassingThreshold = itemByItemPassingThreshold
        self.language = language
    }

    // MARK: - Internal Init (for testing without FoundationModels)

    /// Internal initialiser for unit testing. Accepts a custom judge closure so tests
    /// can run without a real device or Apple Intelligence.
    ///
    /// Access via `@testable import EvalKitFoundationModels`.
    init(
        dimensions: [JudgeDimension],
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

    // MARK: - Report

    /// Run judge evaluation over a batch of test cases and return a `JudgeReport`.
    ///
    /// All cases are evaluated concurrently using `TaskGroup`. For each case, the
    /// `outputProvider` is called first to generate the model's output, then all
    /// configured dimensions are scored via `LLMJudgeRunner`. If `outputProvider`
    /// throws, the case is recorded with an error and no scores — the batch continues
    /// with the remaining cases.
    ///
    /// - Parameters:
    ///   - cases: The test cases to evaluate. Each case is processed as a concurrent task.
    ///   - featureName: Human-readable feature name written into the report header.
    ///   - outputProvider: Closure called once per case to generate the model's response.
    ///     Call your production generative model here. Errors are captured automatically —
    ///     they do not abort the run.
    ///   - keyFactsProvider: Optional closure returning per-case key-facts overrides —
    ///     a dictionary mapping dimension name to the list of facts to verify for that case.
    ///     Required when using `.groundedness()` or `.recall()` dimensions, which have empty
    ///     default fact lists. Pass `nil` (default) to use each dimension's built-in facts.
    ///
    ///   **Common mistake**: omitting `keyFactsProvider` when using `.groundedness()` or
    ///   `.recall()`. Those dimensions have empty default facts — without a provider the
    ///   judge receives no facts to verify and will vacuously score `1.0`.
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
            passedBaseline: passedBaseline,
            baselineDescription: "pass rate >= \(minimumPassRate)"
        )
    }
}
