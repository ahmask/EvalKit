// EvalKit — all processing is on-device. No data leaves the device.
//
// MaxSentencesRule.swift
// EvalKitRules/Rules
//
// Rule that checks the generated output does not exceed a maximum sentence count.

import Foundation

/// A rule that verifies the model output contains at most a specified number of sentences.
///
/// ## Purpose
///
/// `MaxSentencesRule` counts sentence-ending punctuation (`.`, `!`, `?`) in the model
/// output and fails the rule when the count exceeds `maximum`. It is designed for
/// features where response length must be tightly controlled — e.g. short greetings,
/// one-sentence summaries, or single-statement answers.
///
/// ## When to use
///
/// - Use when your feature specification defines an explicit sentence limit:
///   "The greeting must be one sentence", "The confirmation must be two sentences max."
/// - Combine with `MaxWordsRule` to enforce both sentence and word count limits simultaneously.
///
/// ## When not to use
///
/// - When response quality (not length) is the concern. Use `LLMJudgeReporter` to
///   evaluate whether the output is well-written.
/// - When the output uses abbreviations or ellipsis that create false sentence boundaries.
///   The counter counts literal terminator characters (`.`, `!`, `?`) — embedded
///   abbreviations (e.g. "Dr.") will increase the count.
///
/// ## Usage example
///
/// ```swift
/// let rule = MaxSentencesRule(maximum: 1)
/// rule.evaluate(output: "Hello, Maria!", context: [:])       // true  — 1 sentence
/// rule.evaluate(output: "Hello! How are you?", context: [:]) // false — 2 sentences
/// ```
public struct MaxSentencesRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// The maximum number of sentences allowed in the model output.
    ///
    /// Output with exactly `maximum` sentences passes. Output with `maximum + 1` or
    /// more sentences fails. Set to `1` for single-sentence requirements, `2` for
    /// up to two sentences, etc.
    public let maximum: Int

    // MARK: - Init

    /// Create a max-sentences rule.
    ///
    /// - Parameter maximum: The highest sentence count that passes. Outputs with more
    ///   than this many sentences will fail the rule.
    public init(maximum: Int) {
        self.maximum = maximum
    }

    // MARK: - EvaluationRule

    public var name: String { "max_sentences" }

    public var failureMessage: String {
        "Output exceeds maximum of \(maximum) sentences"
    }

    /// Evaluate whether the output has at most `maximum` sentences.
    ///
    /// Counts occurrences of `.`, `!`, and `?` with preceding content. A trailing
    /// content segment without a terminator counts as one additional sentence.
    ///
    /// - Returns: `true` if sentence count ≤ `maximum`, `false` otherwise.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        sentenceCount(in: output) <= maximum
    }

    /// Returns a detailed failure message including the actual sentence count.
    ///
    /// Example: `"Output contains 3 sentences, maximum is 1"`.
    public func failureDescription(for output: String, context: [String: String]) -> String {
        let count = sentenceCount(in: output)
        return "Output contains \(count) sentences, maximum is \(maximum)"
    }

    // MARK: - Private

    private func sentenceCount(in text: String) -> Int {
        let terminators: Set<Character> = [".", "!", "?"]
        var count = 0
        var hasContent = false

        for char in text {
            if !char.isWhitespace { hasContent = true }
            if terminators.contains(char) && hasContent {
                count += 1
                hasContent = false
            }
        }
        // Count a trailing segment that has content but no terminator
        if hasContent { count += 1 }
        return count
    }
}

