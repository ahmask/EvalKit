// EvalKit — all processing is on-device. No data leaves the device.
//
// MockEvaluationRunner.swift
// EvalKitTests

import Foundation
@testable import EvalKit

// MARK: - Mock Case

struct MockCase: EvaluationCase {
    let id: String
    let input: String
    let expectedOutput: String
}

// MARK: - Mock Runner

/// A deterministic EvaluationRunner for use in unit tests.
/// Returns `isCorrect = true` when `predicted == expectedOutput`.
struct MockEvaluationRunner: EvaluationRunner {
    typealias Case = MockCase

    /// The label this runner always returns.
    let predictedLabel: String
    /// Simulated latency in ms.
    let simulatedLatencyMs: Double

    init(predictedLabel: String, simulatedLatencyMs: Double = 10.0) {
        self.predictedLabel = predictedLabel
        self.simulatedLatencyMs = simulatedLatencyMs
    }

    func run(_ testCase: MockCase) async throws -> EvaluationResult {
        let isCorrect = predictedLabel == testCase.expectedOutput
        return EvaluationResult(
            id: testCase.id,
            isCorrect: isCorrect,
            latencyMs: simulatedLatencyMs,
            predictedLabel: predictedLabel,
            expectedLabel: testCase.expectedOutput
        )
    }
}

// MARK: - Mock Runner (always errors)

struct ErrorEvaluationRunner: EvaluationRunner {
    typealias Case = MockCase

    func run(_ testCase: MockCase) async throws -> EvaluationResult {
        return EvaluationResult(
            id: testCase.id,
            isCorrect: false,
            latencyMs: 0,
            predictedLabel: nil,
            expectedLabel: testCase.expectedOutput,
            error: "Simulated error"
        )
    }
}
