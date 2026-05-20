// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationRunner.swift
// EvalKit/Protocols
//
// Protocol for running a single evaluation case and producing an EvaluationResult.

import Foundation

/// Runs a single evaluation test case and returns a raw result.
///
/// ## Purpose
///
/// `EvaluationRunner` is the bridge between your model and the EvalKit measurement
/// system. It calls your model or pipeline for exactly one test case, measures
/// latency, and wraps the outcome in an `EvaluationResult` that reporters can
/// aggregate. You write one concrete runner per feature.
///
/// ## When to use
///
/// Use `EvaluationRunner` when your feature has a deterministic right-or-wrong
/// answer for every input:
/// - Text classification (predicted label vs expected label).
/// - Topic retrieval (predicted topic set vs expected topic set).
/// - Structured output extraction (predicted JSON vs expected JSON via similarity score).
///
/// ## When not to use
///
/// - If your feature generates free-form text where any well-written response is
///   acceptable (greeting generation, summarisation, RAG responses), use
///   `LLMJudgeReporter` (EvalKitJudge) instead. There is no single correct answer
///   to compare against, so a runner's `isCorrect` verdict is meaningless.
/// - If you are evaluating generated output against deterministic rules (max length,
///   valid JSON, language match), use `RulesReporter` (EvalKitRules) instead — it
///   does not need an `EvaluationRunner` conformance.
///
/// ## Usage example
///
/// ```swift
/// // 1. Define your runner
/// struct FeedbackRunner: EvaluationRunner {
///     typealias Case = TextEvaluationCase
///
///     func run(_ testCase: TextEvaluationCase) async throws -> EvaluationResult {
///         var latencyMs: Double = 0
///         let predicted = try await LatencyMeasurer.measure(into: &latencyMs) {
///             try await classifier.predict(testCase.input)
///         }
///         return EvaluationResult(
///             id: testCase.id,
///             isCorrect: predicted == testCase.expectedOutput,
///             latencyMs: latencyMs,
///             predictedLabel: predicted,
///             expectedLabel: testCase.expectedOutput
///         )
///     }
/// }
///
/// // 2. Drive the runner over your dataset
/// let runner = FeedbackRunner()
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// // 3. Pass results to a reporter
/// let report = reporter.report(from: results, featureName: "FeedbackClassification")
/// ```
public protocol EvaluationRunner: Sendable {
    associatedtype Case: EvaluationCase

    /// Run a single test case and return the raw evaluation result.
    ///
    /// Implement this method to call your model with `testCase.input`, measure
    /// latency, and return an `EvaluationResult`. Capture errors inside the result
    /// (set `error:` and `isCorrect: false`) rather than throwing them, so that
    /// a single failure does not abort the entire batch.
    ///
    /// - Parameter testCase: The test case to evaluate. Use `testCase.input` as the
    ///   model input and `testCase.expectedOutput` as the reference to compare against.
    /// - Returns: An `EvaluationResult` describing the outcome of this single case.
    ///
    /// - Note: A common mistake is throwing errors out of `run` instead of capturing
    ///   them in `EvaluationResult.error`. If `run` throws, the caller's batch loop
    ///   will abort and you will lose all subsequent results.
    func run(_ testCase: Case) async throws -> EvaluationResult
}
