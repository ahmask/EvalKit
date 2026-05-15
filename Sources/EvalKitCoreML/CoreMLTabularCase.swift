// EvalKit — all processing is on-device. No data leaves the device.
//
// CoreMLTabularCase.swift
// EvalKitCoreML
//
// EvaluationCase for CoreML tabular classifiers (Create ML Tabular Classification).
// Unlike CoreMLTextCase (which wraps NLModel text classification), tabular classifiers
// receive a feature dictionary of key-value string pairs — one row of the training table.
//
// Typical use: pointwise engagement scorers, binary classifiers trained on categorical
// context features (e.g. flight_phase, membership, booking_class → engaged: 0 | 1).

import Foundation
import EvalKit

/// A single evaluation test case for a CoreML tabular classifier.
///
/// Each case maps a feature dictionary (the input row) to an expected output label.
/// Use `CoreMLTabularRunner` to run a batch of these cases and get an `EvaluationReport`.
///
/// Example (binary engagement classifier):
/// ```swift
/// let case1 = CoreMLTabularCase(
///     id: "boarding-senator",
///     input: [
///         "flight_phase":        "boarding",
///         "membership":          "sen",
///         "booking_class":       "business",
///         "card_id":             "boardingPassCTA"
///     ],
///     expectedOutput: "1"   // engaged
/// )
/// ```
public struct CoreMLTabularCase: EvaluationCase, Sendable {

    /// Stable identifier for this test case.
    public let id: String

    /// Feature dictionary matching the training table column names.
    /// All values are strings — Create ML tabular classifiers accept categorical string inputs.
    public let input: [String: String]

    /// Ground-truth output label as a string (e.g. `"1"` for engaged, `"0"` for not engaged,
    /// or any multi-class label like `"boarding"` for a phase classifier).
    public let expectedOutput: String

    public init(id: String, input: [String: String], expectedOutput: String) {
        self.id = id
        self.input = input
        self.expectedOutput = expectedOutput
    }
}
