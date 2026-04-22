// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelRunner.swift
// EvalKitFoundation
//
// Base runner for Apple Foundation Model evaluation cases.
// Measures latency with LatencyMeasurer and captures errors per case.

import Foundation
import EvalKit

/// Base implementation helper for Foundation Model `EvaluationRunner` conformances.
///
/// Provide a `generate` closure that calls your on-device model and returns:
/// - `(predicted: String, score: Double?, secondaryScore: Double?, hallucinationFlag: Bool)`
///
/// Score semantics:
/// - TopicFinder: `score` = Jaccard similarity, `secondaryScore` = position similarity
/// - PackingList: `score` = 1.0 when isValid, 0.0 otherwise; `secondaryScore` = nil
///
/// Example (TopicFinder):
/// ```swift
/// let runner = FoundationModelRunner { input in
///     let result = try await pipeline.run(prompt: input)
///     let jaccard = JaccardSimilarity.compute(predicted: result.topicIds, expected: expected)
///     let position = PositionSimilarity.compute(predicted: result.topicIds, expected: expected)
///     return (predicted: result.topicIds.joined(separator: ","),
///             score: jaccard, secondaryScore: position, hallucinationFlag: false)
/// }
/// ```
public struct FoundationModelRunner: EvaluationRunner, Sendable {
    public typealias Case = FoundationModelCase

    public struct GenerateResult: Sendable {
        public let predicted: String
        public let score: Double?
        public let secondaryScore: Double?
        public let hallucinationFlag: Bool

        public init(
            predicted: String,
            score: Double? = nil,
            secondaryScore: Double? = nil,
            hallucinationFlag: Bool = false
        ) {
            self.predicted = predicted
            self.score = score
            self.secondaryScore = secondaryScore
            self.hallucinationFlag = hallucinationFlag
        }
    }

    private let generate: @Sendable (String) async throws -> GenerateResult

    public init(generate: @escaping @Sendable (String) async throws -> GenerateResult) {
        self.generate = generate
    }

    /// Run a single Foundation Model test case, measure latency, and return a result.
    ///
    /// ## `isCorrect` semantics
    ///
    /// The determination of correctness depends on what your `generate` closure returns:
    ///
    /// - **When `score` is provided** (e.g. Jaccard similarity from TopicFinder):
    ///   `isCorrect = score >= 1.0` — exact match only.
    ///
    /// - **When `score` is `nil`** (e.g. plain text classification):
    ///   `isCorrect = predicted.lowercased().contains(expectedOutput.lowercased())`
    ///   This is a case-insensitive substring match. It is intentionally lenient to
    ///   handle LLM outputs that include light surrounding text (e.g. "Category: baggage").
    ///   If your feature requires exact string equality, normalise the predicted output
    ///   inside your `generate` closure before returning it, and leave `score` nil.
    public func run(_ testCase: FoundationModelCase) async throws -> EvaluationResult {
        var latencyMs: Double = 0
        do {
            let output = try await LatencyMeasurer.measure(into: &latencyMs) {
                try await generate(testCase.input)
            }
            let isCorrect: Bool
            if let s = output.score {
                isCorrect = s >= 1.0
            } else {
                isCorrect = output.predicted.lowercased().contains(
                    testCase.expectedOutput.lowercased()
                )
            }
            return EvaluationResult(
                id: testCase.id,
                isCorrect: isCorrect,
                latencyMs: latencyMs,
                predictedLabel: output.predicted,
                expectedLabel: testCase.expectedOutput,
                score: output.score,
                secondaryScore: output.secondaryScore,
                hallucinationFlag: output.hallucinationFlag
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
