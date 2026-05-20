// EvalKit — all processing is on-device. No data leaves the device.
//
// ValidJSONRule.swift
// EvalKitRules/Rules
//
// Rule that checks the generated output is valid JSON, optionally with required keys.

import Foundation

/// A rule that verifies the model output is valid JSON, with an optional check for
/// required top-level keys.
///
/// ## Purpose
///
/// `ValidJSONRule` attempts to parse the model output as JSON using `JSONSerialization`.
/// It fails if the output is not parseable JSON, or if specified required top-level keys
/// are missing from the parsed dictionary. Use it as a format gate before checking the
/// content of structured outputs.
///
/// ## When to use
///
/// - Use for any feature that must return structured JSON output: packing list generation,
///   flight data extraction, any feature using structured model output.
/// - Combine with `AllowedItemsRule` to first validate JSON structure, then validate content:
///   `ValidJSONRule` ensures the output is parseable before `AllowedItemsRule` checks vocabulary.
///
/// ## When not to use
///
/// - For free-form text generation. JSON rules only apply to features that produce JSON.
/// - For deep schema validation (nested keys, array lengths, value types). For complex
///   schemas, consider a custom `EvaluationRule` that uses `Codable` decoding.
///
/// ## Usage example
///
/// ```swift
/// // Just validate JSON
/// let jsonRule = ValidJSONRule()
///
/// // Validate JSON and require specific top-level keys
/// let strictRule = ValidJSONRule(requiredKeys: ["items", "destination"])
///
/// strictRule.evaluate(output: #"{"items": [], "destination": "Munich"}"#, context: [:]) // true
/// strictRule.evaluate(output: #"{"items": []}"#, context: [:])                          // false — missing key
/// strictRule.evaluate(output: "not json", context: [:])                                 // false — invalid JSON
/// ```
public struct ValidJSONRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// Top-level keys that must be present in the parsed JSON object.
    ///
    /// Empty (default) = only validate that the output is parseable JSON, no key checks.
    /// Non-empty = validate JSON AND check that all listed keys exist at the top level of
    /// the parsed dictionary. If the JSON is valid but not a dictionary (e.g. a JSON array),
    /// the key check fails automatically.
    public let requiredKeys: [String]

    // MARK: - Init

    /// Create a JSON validation rule.
    ///
    /// - Parameter requiredKeys: Top-level dictionary keys that must be present in the output.
    ///   Defaults to `[]` (validate JSON structure only, no key requirements). Pass key names
    ///   that your model must always include in its output (e.g. `["items", "destination"]`).
    public init(requiredKeys: [String] = []) {
        self.requiredKeys = requiredKeys
    }

    // MARK: - EvaluationRule

    public var name: String { "valid_json" }

    public var failureMessage: String { "Output is not valid JSON" }

    /// Evaluate whether the output is valid JSON and contains all required keys.
    ///
    /// - Returns: `true` if the output parses as valid JSON and all `requiredKeys` are
    ///   present at the top level. `false` if the output is not valid JSON, or if any
    ///   required key is missing, or if the JSON is not a dictionary when keys are required.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        guard let data = output.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data)
        else { return false }

        guard !requiredKeys.isEmpty else { return true }
        guard let dict = parsed as? [String: Any] else { return false }
        return requiredKeys.allSatisfy { dict[$0] != nil }
    }

    /// Returns a detailed failure description including which required keys are missing.
    ///
    /// Examples:
    /// - `"Output is not valid JSON"`
    /// - `"Output is valid JSON but not an object (dictionary)"`
    /// - `"Output is missing required keys: destination, currency"`
    public func failureDescription(for output: String, context: [String: String]) -> String {
        guard let data = output.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data)
        else { return "Output is not valid JSON" }

        guard !requiredKeys.isEmpty else { return failureMessage }
        guard let dict = parsed as? [String: Any] else {
            return "Output is valid JSON but not an object (dictionary)"
        }
        let missing = requiredKeys.filter { dict[$0] == nil }
        return missing.isEmpty
            ? failureMessage
            : "Output is missing required keys: \(missing.joined(separator: ", "))"
    }
}
