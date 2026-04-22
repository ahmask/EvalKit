// EvalKit — all processing is on-device. No data leaves the device.
//
// CoreMLLatencyRunner.swift
// EvalKitCoreML
//
// Base class pattern for CoreML EvaluationRunners that measure latency and
// track errors per case.

import Foundation
import CoreML
import EvalKit

/// Base implementation helper for CoreML classification evaluation runners.
///
/// Subclass or use as a reference to implement your feature's `EvaluationRunner`.
/// Handles latency measurement via `LatencyMeasurer` and wraps errors into
/// `EvaluationResult.error` instead of propagating them.
///
/// The `classify` closure receives raw input text and must return the model's
/// predicted label string. Throw any `Error` to record it as a case error.
///
/// Example usage:
/// ```swift
/// let runner = CoreMLLatencyRunner { text in
///     try myModel.prediction(text: text).label
/// }
/// let result = try await runner.run(myCase)
/// ```
public struct CoreMLLatencyRunner: EvaluationRunner, Sendable {
    public typealias Case = CoreMLTextCase

    private let classify: @Sendable (String) throws -> String

    /// Create a runner with a synchronous CoreML classify closure.
    ///
    /// - Parameter classify: Closure that runs CoreML inference and returns the top label.
    public init(classify: @escaping @Sendable (String) throws -> String) {
        self.classify = classify
    }

    public func run(_ testCase: CoreMLTextCase) async throws -> EvaluationResult {
        var latencyMs: Double = 0
        do {
            let predicted = try await LatencyMeasurer.measure(into: &latencyMs) {
                try classify(testCase.input)
            }
            let isCorrect = predicted == testCase.expectedOutput
            return EvaluationResult(
                id: testCase.id,
                isCorrect: isCorrect,
                latencyMs: latencyMs,
                predictedLabel: predicted,
                expectedLabel: testCase.expectedOutput
            )
        } catch {
            return EvaluationResult(
                id: testCase.id,
                isCorrect: false,
                latencyMs: latencyMs,
                predictedLabel: nil,
                expectedLabel: testCase.expectedOutput,
                error: error.localizedDescription
            )
        }
    }
}
