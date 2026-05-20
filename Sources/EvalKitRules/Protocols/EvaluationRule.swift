// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationRule.swift
// EvalKitRules/Protocols
//
// Protocol for a single deterministic rule applied to model output text.

import Foundation

/// A single deterministic rule applied to a model's generated output.
///
/// ## Purpose
///
/// Rules are **deterministic** — no LLM, no randomness, no network calls. The same
/// input always produces the same result. `EvaluationRule` defines the interface for
/// all checks that can be expressed as code: length limits, vocabulary restrictions,
/// format validation, regex patterns, and language detection.
///
/// `RulesReporter` evaluates every configured rule against every test case concurrently
/// and aggregates pass rates, violation counts, and per-case details into a `RulesReport`.
///
/// ## When to use
///
/// Use `EvaluationRule` for any output property that can be checked mechanically:
/// - **Length**: Output must not exceed N words or N sentences → `MaxWordsRule`, `MaxSentencesRule`
/// - **Vocabulary**: Output must only use items from an approved list → `AllowedItemsRule`
/// - **Format**: Output must be valid JSON → `ValidJSONRule`
/// - **Pattern**: Output must match or not match a regex → `RegexRule`
/// - **Language**: Output must be written in a specific language → `LanguageMatchRule`
///
/// ## When not to use
///
/// Rules cannot catch things that require judgment:
///
/// | Checkable with code? | Use | Example |
/// |---|---|---|
/// | Yes | `EvaluationRule` | Output exceeds 50 words |
/// | Yes | `EvaluationRule` | Output is not valid JSON |
/// | No  | `JudgeRunner` (EvalKitJudge) | Output is natural-sounding |
/// | No  | `JudgeRunner` (EvalKitJudge) | Tone is appropriate for a customer |
///
/// ## Conformance
///
/// Implement `evaluate(output:context:)` to check your rule. Return `true` if the
/// output passes, `false` if it violates this rule.
///
/// ```swift
/// struct NoEmptyOutputRule: EvaluationRule {
///     let name = "no_empty_output"
///     let failureMessage = "Output was empty"
///     func evaluate(output: String, context: [String: String]) -> Bool {
///         !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
///     }
/// }
/// ```
public protocol EvaluationRule: Sendable {

    /// Human-readable name identifying this rule.
    ///
    /// Examples: `"max_sentences"`, `"valid_json"`, `"language_match"`.
    /// Used as the key in `RulesReport.violationSummary` and in `RuleViolation.ruleName`.
    /// Keep it stable — changing it between runs breaks violation trend comparisons.
    var name: String { get }

    /// Static failure message for this rule.
    ///
    /// Should describe what the rule requires, e.g. `"Output exceeds maximum word count"`.
    /// For rules that include specific observed values (e.g. actual word count), override
    /// `failureDescription(for:context:)` instead to produce a more informative message.
    var failureMessage: String { get }

    /// Evaluate whether the model's output passes this rule.
    ///
    /// Called by `RulesReporter` for every test case. Must be deterministic — the same
    /// `output` and `context` must always return the same result.
    ///
    /// - Parameters:
    ///   - output: The model's generated text for this test case.
    ///   - context: Optional key-value pairs from the test case providing additional
    ///     evaluation context (e.g. `["language": "de", "destination": "Munich"]`).
    /// - Returns: `true` if the output satisfies the rule, `false` if it violates it.
    func evaluate(output: String, context: [String: String]) -> Bool
}

public extension EvaluationRule {
    /// Returns a detailed failure description for a specific output string.
    ///
    /// The default implementation returns the static `failureMessage`. Rules that
    /// produce context-dependent messages (e.g. "Output contains 8 sentences, maximum
    /// is 2") override this method to include the actual observed value.
    ///
    /// `RulesReporter` calls this method — not `failureMessage` directly — so overriding
    /// this method is the recommended way to produce informative violation messages.
    func failureDescription(for output: String, context: [String: String]) -> String {
        failureMessage
    }
}
