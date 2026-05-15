// EvalKit — all processing is on-device. No data leaves the device.
//
// CoreMLTabularRunner.swift
// EvalKitCoreML
//
// EvaluationRunner for CoreML tabular classifiers.
// Mirrors CoreMLLatencyRunner but accepts feature dictionaries instead of raw text,
// making it suitable for Create ML Tabular Classification models.
//
// Usage pattern:
//   1. Build a [String: MLFeatureValue] dictionary from the CoreMLTabularCase input.
//   2. Call model.prediction(from: MLDictionaryFeatureProvider).
//   3. Extract the predicted label string from the output.
//   4. Return the label — the runner compares it to expectedOutput and measures latency.

import Foundation
import CoreML
import EvalKit

/// Runs a single `CoreMLTabularCase` through a tabular CoreML classifier and returns an
/// `EvaluationResult` with latency, correctness, and predicted vs expected labels.
///
/// Provide a `classify` closure that translates the feature dictionary into a CoreML
/// prediction and returns the top predicted label string.
///
/// ```swift
/// let runner = CoreMLTabularRunner { features in
///     let mlFeatures = try features.mapValues { MLFeatureValue(string: $0) }
///     let provider   = try MLDictionaryFeatureProvider(dictionary: mlFeatures)
///     let output     = try model.prediction(from: provider)
///     return output.featureValue(for: "label")?.stringValue ?? ""
/// }
/// let result = try await runner.run(myCase)
/// ```
///
/// For ranking evaluation (find the top-scored card from a candidate set), wrap the
/// full scoring loop in the closure and return the winning candidate's ID as the label.
/// Set `expectedOutput` to the expected winner's ID and correctness is handled automatically.
public struct CoreMLTabularRunner: EvaluationRunner, Sendable {
    public typealias Case = CoreMLTabularCase

    private let classify: @Sendable ([String: String]) throws -> String

    /// Create a runner with a synchronous CoreML classify closure.
    ///
    /// - Parameter classify: Receives the feature dictionary from `CoreMLTabularCase.input`
    ///   and must return the top predicted label. Throw any `Error` to record it as a case error.
    public init(classify: @escaping @Sendable ([String: String]) throws -> String) {
        self.classify = classify
    }

    public func run(_ testCase: CoreMLTabularCase) async throws -> EvaluationResult {
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
