// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationRunner.swift
// EvalKit/Protocols
//
// Protocol for running a single evaluation case and producing an EvaluationResult.

import Foundation

/// Runs a single evaluation test case and returns a raw result.
///
/// Implement `run(_:)` to call your model or pipeline and wrap the outcome in
/// an `EvaluationResult`. The caller (your `EvaluationReporter`) aggregates
/// the results into an `EvaluationReport`.
///
/// Example:
/// ```swift
/// struct FeedbackRunner: EvaluationRunner {
///     typealias Case = FeedbackCase
///     func run(_ testCase: FeedbackCase) async throws -> EvaluationResult {
///         let start = Date()
///         let predicted = try await classifier.predict(testCase.input)
///         let latency = Date().timeIntervalSince(start) * 1000
///         return EvaluationResult(
///             id: testCase.id,
///             isCorrect: predicted == testCase.expectedOutput,
///             latencyMs: latency,
///             predictedLabel: predicted,
///             expectedLabel: testCase.expectedOutput
///         )
///     }
/// }
/// ```
public protocol EvaluationRunner: Sendable {
    associatedtype Case: EvaluationCase

    /// Run a single test case and return the raw evaluation result.
    func run(_ testCase: Case) async throws -> EvaluationResult
}
