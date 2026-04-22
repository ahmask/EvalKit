// EvalKit — all processing is on-device. No data leaves the device.
//
// CoreMLEvaluationCase.swift
// EvalKitCoreML
//
// Convenience EvaluationCase implementation for CoreML text-classification features.

import Foundation
import CoreML
import EvalKit

/// A ready-made `EvaluationCase` for CoreML text-classification evaluations.
///
/// Wrap each row in your labeled test dataset with `CoreMLTextCase` and pass
/// the array to a `CoreMLLatencyRunner`.
///
/// ```swift
/// let cases = dataset.map {
///     CoreMLTextCase(id: "\($0.id)", input: $0.text, expectedOutput: $0.label)
/// }
/// ```
public struct CoreMLTextCase: EvaluationCase, Sendable {
    public let id: String
    /// Raw input text to classify.
    public let input: String
    /// Ground-truth label string (e.g. `HelpCategory.rawValue`).
    public let expectedOutput: String

    public init(id: String, input: String, expectedOutput: String) {
        self.id = id
        self.input = input
        self.expectedOutput = expectedOutput
    }
}
