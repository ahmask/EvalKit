// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationCase.swift
// EvalKit/Protocols
//
// Protocol for a single evaluation test case with associated input and expected output.

import Foundation

/// The foundation protocol for a single evaluation test case.
///
/// ## Purpose
///
/// Every EvalKit evaluation starts with a dataset of test cases. `EvaluationCase`
/// defines the minimum shape of each case — a stable identifier, the input to feed
/// the model, and the expected output to compare against. Conform to this protocol
/// to describe your feature's input/output contract to the evaluation system.
///
/// ## When to use
///
/// Conform to `EvaluationCase` when your feature has a fixed input format and a known
/// expected output for each test input. Typical conformers:
/// - A classification case carrying a user query and its correct category label.
/// - A retrieval case carrying a search query and its expected topic list.
/// - A packing list case carrying flight details and an expected JSON structure.
///
/// ## When not to use
///
/// - If all your inputs and expected outputs are plain `String` values, use
///   `TextEvaluationCase` directly — it is a ready-made concrete conformer that
///   covers all string-in / string-out features.
/// - If you are evaluating free-form generation quality where there is no single
///   correct answer, use `TextEvaluationCase` with an empty `expectedOutput` and
///   route results through `LLMJudgeReporter` (EvalKitJudge). The judge evaluates
///   quality, not exact match, so a fixed expected value is not needed.
///
/// ## Usage example
///
/// ```swift
/// // 1. Define your concrete case type
/// struct RecipeCase: EvaluationCase {
///     let id: String
///     let input: String           // e.g. "Pasta with tomato sauce"
///     let expectedOutput: String  // e.g. "italian"
/// }
///
/// // 2. Build your dataset
/// let cases: [RecipeCase] = dataset.map {
///     RecipeCase(id: $0.id, input: $0.text, expectedOutput: $0.category)
/// }
///
/// // 3. Run each case through your runner
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// // 4. Aggregate into a report
/// let reporter = StandardClassificationReporter(
///     labels: RecipeCategory.allCases.map(\.rawValue),
///     minimumAccuracy: 0.85
/// )
/// let report = reporter.report(from: results, featureName: "RecipeClassifier")
/// print(report.passedBaseline)
/// ```
public protocol EvaluationCase: Sendable {
    associatedtype Input: Sendable
    associatedtype ExpectedOutput: Sendable

    /// Stable identifier for this test case.
    ///
    /// Used to correlate raw `EvaluationResult` values back to their source case
    /// when debugging failures. Choose any identifier that is unique within your
    /// dataset and stable across evaluation runs — an integer index cast to `String`,
    /// a UUID, or a descriptive slug like `"feedback-baggage-lost-001"`.
    ///
    /// Avoid changing `id` values between runs if you want to track per-case
    /// regressions over time.
    var id: String { get }

    /// The input passed to the model or pipeline under evaluation.
    ///
    /// The concrete type is defined by your `EvaluationCase` conformance. For text
    /// features this is typically a `String`. For structured features it may be a
    /// domain-specific struct. The runner receives this value directly and passes it
    /// to the model; the reporter does not use it.
    var input: Input { get }

    /// The ground-truth expected output for this input.
    ///
    /// For classification: the correct label string (e.g. `"baggage"`).
    /// For retrieval: the expected ranked list or topic set (e.g. a comma-separated string).
    /// For text generation evaluated by rules or a judge: pass an empty string — correctness
    /// is assessed by rules or the LLM judge, not by comparing to a fixed expected value.
    var expectedOutput: ExpectedOutput { get }
}
