// EvalKit — all processing is on-device. No data leaves the device.
//
// RegexRule.swift
// EvalKitRules/Rules
//
// Rule that validates model output against a regular expression pattern.

import Foundation

/// A rule that checks whether a model output matches (or does not match) a regex pattern.
///
/// ## Purpose
///
/// `RegexRule` validates model output against an `NSRegularExpression` pattern. It
/// supports two modes: require a match (`mustMatch = true`) or require no match
/// (`mustMatch = false`). This makes it suitable for both presence and absence checks.
///
/// ## When to use
///
/// - **Presence check**: The output must contain a flight number, a booking reference,
///   a specific greeting word, or start with a specific salutation.
/// - **Absence check**: The output must not contain PII (email addresses, phone numbers),
///   forbidden words, or markup that should have been stripped.
///
/// ```swift
/// // Output must start with "Dear" (salutation check)
/// let salutationRule = RegexRule(pattern: "^Dear", name: "salutation_required")
///
/// // Output must NOT contain an email address (PII prevention)
/// let noPIIRule = RegexRule(
///     pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
///     name: "no_email_pii",
///     mustMatch: false
/// )
/// ```
///
/// ## When not to use
///
/// - When the check requires understanding of meaning or context. Use `LLMJudgeReporter`
///   for semantic checks.
/// - When you need to validate the entire output format. Use `ValidJSONRule` for
///   JSON format validation or `AllowedItemsRule` for vocabulary checks.
///
/// - Note: If `pattern` is an invalid regular expression, `evaluate` returns `false`
///   (treated as a rule failure) to surface the configuration error rather than silently passing.
public struct RegexRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// The regular expression pattern string.
    ///
    /// Must be a valid `NSRegularExpression` pattern. If the pattern is invalid,
    /// `evaluate` returns `false` for every output, surfacing the misconfiguration.
    /// Test your pattern with `NSRegularExpression(pattern:)` during development.
    public let pattern: String

    /// Human-readable identifier for this rule instance.
    ///
    /// Used as the key in `RulesReport.violationSummary` and in `RuleViolation.ruleName`.
    /// Make it descriptive and stable, e.g. `"salutation_required"` or `"no_email_pii"`.
    public let name: String

    /// Whether the output must match (`true`) or must NOT match (`false`) the pattern.
    ///
    /// `true` (default): the output must contain at least one match for the rule to pass.
    ///   Use for presence checks — the output must have a flight number, a specific word, etc.
    /// `false`: the output must contain zero matches for the rule to pass.
    ///   Use for absence checks — the output must not contain PII or forbidden patterns.
    public let mustMatch: Bool

    // MARK: - Init

    /// Create a regex rule.
    ///
    /// - Parameters:
    ///   - pattern: A valid `NSRegularExpression` pattern string. Invalid patterns
    ///     cause `evaluate` to always return `false`.
    ///   - name: Human-readable rule identifier used in violation reports.
    ///   - mustMatch: When `true`, the output must match for the rule to pass.
    ///     When `false`, the output must NOT match. Defaults to `true`.
    public init(pattern: String, name: String, mustMatch: Bool = true) {
        self.pattern = pattern
        self.name = name
        self.mustMatch = mustMatch
    }

    // MARK: - EvaluationRule

    public var failureMessage: String {
        mustMatch
            ? "Output does not match required pattern: \(pattern)"
            : "Output contains forbidden pattern: \(pattern)"
    }

    /// Evaluate whether the output satisfies the regex requirement.
    ///
    /// Returns `true` if:
    /// - `mustMatch == true` and the pattern is found at least once in the output, or
    /// - `mustMatch == false` and the pattern is NOT found in the output.
    ///
    /// - Note: If `pattern` is an invalid regular expression, returns `false` to surface
    ///   the configuration error. Check your pattern string if all cases unexpectedly fail.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false  // Invalid pattern — fail safely
        }
        let range = NSRange(output.startIndex..., in: output)
        let matches = regex.firstMatch(in: output, range: range) != nil
        return mustMatch ? matches : !matches
    }
}
