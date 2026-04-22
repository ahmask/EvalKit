// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationCase.swift
// EvalKit/Protocols
//
// Protocol for a single evaluation test case with associated input and expected output.

import Foundation

/// A single evaluation test case.
///
/// Conform to this protocol to define the input/output shape for your feature's
/// evaluation dataset. Each case has a stable `id` for tracking results.
///
/// Example:
/// ```swift
/// struct FeedbackCase: EvaluationCase {
///     let id: String
///     let input: String          // user query text
///     let expectedOutput: String // expected HelpCategory raw value
/// }
/// ```
public protocol EvaluationCase: Sendable {
    associatedtype Input: Sendable
    associatedtype ExpectedOutput: Sendable

    /// Stable identifier for this test case (used for result tracking and reporting).
    var id: String { get }

    /// The input passed to the model or evaluation logic.
    var input: Input { get }

    /// The ground-truth expected output for this input.
    var expectedOutput: ExpectedOutput { get }
}
