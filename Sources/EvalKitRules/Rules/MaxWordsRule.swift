// EvalKit — all processing is on-device. No data leaves the device.
//
// MaxWordsRule.swift
// EvalKitRules/Rules
//
// Rule that checks the generated output does not exceed a maximum word count.

import Foundation

/// A rule that verifies the model output contains at most a specified number of words.
///
/// ## Purpose
///
/// `MaxWordsRule` counts whitespace-delimited tokens in the model output and fails the
/// rule when the count exceeds `maximum`. Use it to enforce strict response length limits
/// for features where verbosity is a quality problem — confirmation messages, notifications,
/// single-phrase summaries.
///
/// ## When to use
///
/// - Use when your feature specification defines a word limit:
///   "The notification must be 20 words or fewer."
/// - Combine with `MaxSentencesRule` to enforce both sentence and word count simultaneously.
///
/// ## When not to use
///
/// - When the concern is quality, not length. Use `LLMJudgeReporter` to assess whether
///   the output is well-written or appropriately concise.
/// - For structured outputs (JSON, comma-separated lists): the word count may not be the
///   right metric. Use `ValidJSONRule` or `AllowedItemsRule` for structured checks.
///
/// ## Usage example
///
/// ```swift
/// let rule = MaxWordsRule(maximum: 20)
/// rule.evaluate(output: "Your booking is confirmed.", context: [:])  // true  — 4 words
/// rule.evaluate(output: "Your flight booking has been successfully confirmed and...", context: [:])
/// // false if > 20 words
/// ```
public struct MaxWordsRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// The maximum number of whitespace-delimited words allowed in the output.
    ///
    /// Output with exactly `maximum` words passes. Output with `maximum + 1` or more
    /// words fails. Set based on your feature specification (e.g. `20` for a
    /// short confirmation message, `5` for a single-phrase label).
    public let maximum: Int

    // MARK: - Init

    /// Create a max-words rule.
    ///
    /// - Parameter maximum: The highest word count that passes. Output with more
    ///   words than this threshold will fail the rule.
    public init(maximum: Int) {
        self.maximum = maximum
    }

    // MARK: - EvaluationRule

    public var name: String { "max_words" }

    public var failureMessage: String {
        "Output exceeds maximum of \(maximum) words"
    }

    /// Evaluate whether the output has at most `maximum` words.
    ///
    /// Words are counted by splitting on whitespace and filtering empty segments.
    /// Punctuation attached to a word (e.g. "confirmed.") counts as part of that word.
    ///
    /// - Returns: `true` if word count ≤ `maximum`, `false` otherwise.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        wordCount(in: output) <= maximum
    }

    /// Returns a detailed failure message including the actual word count.
    ///
    /// Example: `"Output contains 27 words, maximum is 20"`.
    public func failureDescription(for output: String, context: [String: String]) -> String {
        let count = wordCount(in: output)
        return "Output contains \(count) words, maximum is \(maximum)"
    }

    // MARK: - Private

    private func wordCount(in text: String) -> Int {
        text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .count
    }
}
