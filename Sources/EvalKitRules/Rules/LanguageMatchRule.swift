// EvalKit — all processing is on-device. No data leaves the device.
//
// LanguageMatchRule.swift
// EvalKitRules/Rules
//
// Rule that checks the generated output is written in the expected language.

import Foundation
import NaturalLanguage

/// A rule that verifies the model output is written in the expected language.
///
/// ## Purpose
///
/// `LanguageMatchRule` detects the dominant language of the model output using
/// Apple's `NaturalLanguage` framework (`NLLanguageRecognizer`) and compares it
/// against a configurable expected BCP-47 language tag. It fires when the output
/// is in the wrong language.
///
/// ## When to use
///
/// Use `LanguageMatchRule` for multilingual generation features where the model must
/// respond in the user's language. For example, if your app supports German and the
/// model generates a greeting, this rule verifies the output is in German.
///
/// ```swift
/// let rule = LanguageMatchRule(expectedLanguage: "de")
/// rule.evaluate(output: "Guten Morgen!", context: [:])   // true  — detected "de"
/// rule.evaluate(output: "Good morning!", context: [:])   // false — detected "en"
/// ```
///
/// ## When not to use
///
/// - Language detection is probabilistic. On very short outputs (1–2 words), confidence
///   may be low and the rule may produce false positives. For short greetings, verify
///   with a larger sample of test cases and review failures manually.
/// - If your expected language varies per test case (not fixed), pass it via the
///   `context` dictionary and create a custom rule that reads `context["language"]`.
///
/// ## Supported BCP-47 codes
///
/// `en`, `de`, `de-AT`, `de-CH`, `it`, `es`, `pt`, `el`, `nl`, `fr`, `tr`,
/// `pl`, `ru`, `zh`, `ja`, `ar`.
/// Regional variants like `de-AT` are matched by checking the base language prefix.
public struct LanguageMatchRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// The BCP-47 language tag the output must be written in.
    ///
    /// Examples: `"en"` (English), `"de"` (German), `"de-AT"` (Austrian German), `"fr"` (French).
    /// Base codes like `"de"` match all regional variants (`de`, `de-AT`, `de-CH`).
    /// Regional codes like `"de-AT"` require an exact regional match.
    public let expectedLanguage: String

    // MARK: - Init

    /// Create a language match rule.
    ///
    /// - Parameter expectedLanguage: The BCP-47 language tag the output must be in.
    ///   Pass a base code (e.g. `"de"`) to match all regional variants, or a regional
    ///   code (e.g. `"de-AT"`) for an exact regional match.
    public init(expectedLanguage: String) {
        self.expectedLanguage = expectedLanguage
    }

    // MARK: - EvaluationRule

    public var name: String { "language_match" }

    public var failureMessage: String {
        "Output is not in the expected language: \(expectedLanguage)"
    }

    /// Evaluate whether the output is written in `expectedLanguage`.
    ///
    /// Runs `NLLanguageRecognizer` on the output to detect its dominant language,
    /// then checks whether the detected code matches `expectedLanguage` (including
    /// regional variant matching). Returns `false` if the language cannot be detected.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        let detected = detectLanguage(in: output)
        return languagesMatch(detected: detected, expected: expectedLanguage)
    }

    /// Returns a detailed failure description including the detected language.
    ///
    /// Example: `"Output is in en, expected de"`.
    public func failureDescription(for output: String, context: [String: String]) -> String {
        let detected = detectLanguage(in: output) ?? "unknown"
        return "Output is in \(detected), expected \(expectedLanguage)"
    }

    // MARK: - Private

    private func detectLanguage(in text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    /// Matches language codes allowing regional variants.
    /// "de" matches "de", "de-AT", "de-CH". "de-AT" requires exactly "de-AT".
    private func languagesMatch(detected: String?, expected: String) -> Bool {
        guard let detected else { return false }
        // Exact match first
        if detected == expected { return true }
        // Check if expected is a base code and detected starts with it
        if !expected.contains("-") && detected.hasPrefix(expected) { return true }
        // Check if both share the same base language code
        let expectedBase = expected.components(separatedBy: "-").first ?? expected
        let detectedBase = detected.components(separatedBy: "-").first ?? detected
        return expectedBase == detectedBase
    }
}
