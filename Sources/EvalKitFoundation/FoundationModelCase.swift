// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelCase.swift
// EvalKitFoundation
//
// Convenience EvaluationCase for Apple Foundation Model features
// (TopicFinder, PackingList).

import Foundation
import EvalKit

/// A generic `EvaluationCase` for Foundation Model features.
///
/// Use for any feature whose input is a `String` prompt and whose expected
/// output is also a `String` (a label, an array encoded as JSON, or a
/// pass/fail indicator).
///
/// TopicFinder example:
/// ```swift
/// let c = FoundationModelCase(
///     id: testCase.id.uuidString,
///     input: testCase.prompt,
///     expectedOutput: testCase.groundtruth   // JSON-encoded [String]
/// )
/// ```
///
/// PackingList example:
/// ```swift
/// let c = FoundationModelCase(
///     id: testCase.id,
///     input: bookingJSON,
///     expectedOutput: "correct format"  // passed when evaluationResult contains this
/// )
/// ```
public struct FoundationModelCase: EvaluationCase, Sendable {
    public let id: String
    public let input: String
    public let expectedOutput: String

    public init(id: String, input: String, expectedOutput: String) {
        self.id = id
        self.input = input
        self.expectedOutput = expectedOutput
    }
}
