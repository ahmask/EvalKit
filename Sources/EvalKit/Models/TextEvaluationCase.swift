// EvalKit — all processing is on-device. No data leaves the device.
//
// TextEvaluationCase.swift
// EvalKit/Models
//
// A generic EvaluationCase for any feature whose input and expected output are Strings.
// Use this for text classification, text generation, summarisation, or any string-in/out task.

import Foundation

/// A ready-to-use `EvaluationCase` for any feature whose input and expected output are `String` values.
///
/// ## Purpose
///
/// `TextEvaluationCase` saves you from defining a custom `EvaluationCase` conformance
/// for the common case where both your model input and your expected output are plain strings.
/// It is intentionally generic — it works with any reporter or runner across EvalKitClassification,
/// EvalKitRetrieval, EvalKitRules, and EvalKitJudge.
///
/// ## When to use
///
/// Use `TextEvaluationCase` when:
/// - Your model takes a text string as input: a user query, a sentence, flight details, a prompt.
/// - Your expected output is a string: a category label, a comma-separated topic list, a JSON string.
/// - You are evaluating free-form generation quality (e.g. greeting generation) where
///   `expectedOutput` is empty and a rules reporter or judge determines correctness.
///
/// `TextEvaluationCase` covers text classification, topic retrieval, RAG topic finding,
/// packing list generation, greeting generation, summarisation — any feature that is
/// string-in / string-out.
///
/// ## When not to use
///
/// - If your model input is not a plain string (e.g. an image, a structured struct, or a
///   multi-modal payload), define a custom `EvaluationCase` conformance instead.
/// - If your expected output is not a string (e.g. a `[String]` ranked list that you want
///   type-safe access to), a custom conformer gives you better type safety.
///
/// ## Usage examples
///
/// ```swift
/// // Classification — input is a user query, expected is a category label
/// let cases = [
///     TextEvaluationCase(id: "1", input: "My bag is lost", expectedOutput: "baggage"),
///     TextEvaluationCase(id: "2", input: "I need a new seat", expectedOutput: "seating"),
/// ]
///
/// // Retrieval — input is a search query, expected is a comma-separated topic list
/// let cases = [
///     TextEvaluationCase(id: "r1", input: "what flights go to Munich?",
///                        expectedOutput: "flights,destinations,booking"),
/// ]
///
/// // Rules/judge evaluation — no single correct answer, expected is empty
/// let cases = [
///     TextEvaluationCase(id: "g1",
///                        input: "Passenger: Maria, Flight: LH400, Destination: Munich",
///                        expectedOutput: ""),
/// ]
/// ```
public struct TextEvaluationCase: EvaluationCase, Sendable {

    // MARK: - EvaluationCase

    /// Stable identifier for this test case.
    ///
    /// Used to correlate raw results back to their source when reviewing failures.
    /// Must be unique within your dataset. Use a sequential integer (as String),
    /// a UUID, or a descriptive slug like `"baggage-lost-001"`.
    public let id: String

    /// The text input passed to the model or pipeline under evaluation.
    ///
    /// This is the exact string your runner will forward to the model —
    /// a user query, a context block, a system prompt, or any text the model processes.
    /// The runner receives this value via `testCase.input`.
    public let input: String

    /// The ground-truth expected output for comparison.
    ///
    /// For classification: the correct label string (e.g. `"baggage"`).
    /// For retrieval: the expected comma-separated topic list (e.g. `"flights,booking"`).
    /// For rules or judge evaluation: pass an empty string — correctness is determined by
    /// rules or the LLM judge, not by comparing to a fixed expected value.
    public let expectedOutput: String

    // MARK: - Init

    /// Create a text evaluation case.
    ///
    /// - Parameters:
    ///   - id: Stable identifier for result tracking and reporting.
    ///   - input: The text prompt or context passed to the model.
    ///   - expectedOutput: The reference output for comparison. Pass an empty string
    ///     when a rules reporter or judge reporter evaluates correctness.
    public init(id: String, input: String, expectedOutput: String) {
        self.id = id
        self.input = input
        self.expectedOutput = expectedOutput
    }
}
