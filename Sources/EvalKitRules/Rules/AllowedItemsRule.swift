// EvalKit — all processing is on-device. No data leaves the device.
//
// AllowedItemsRule.swift
// EvalKitRules/Rules
//
// Rule that validates all items in the model output belong to a predefined allowed list.

import Foundation

/// A rule that validates all generated items belong to a predefined allowed vocabulary.
///
/// ## Purpose
///
/// `AllowedItemsRule` checks that every item the model generates belongs to a known,
/// finite vocabulary. It parses the model output using a caller-supplied `extractItems`
/// closure, then flags any item that does not appear in the `allowedItems` dictionary.
///
/// ## When to use
///
/// - Use when your feature produces structured output from a **known, finite set** of
///   values, e.g. a packing list, a category list, a product catalogue, or a topic set.
/// - The extraction approach is flexible: the closure can parse JSON, split on commas,
///   extract tagged lines, or apply any custom parsing logic.
///
/// ## When not to use
///
/// - When the valid output space is **open-ended** or requires language understanding
///   (e.g. "is this greeting natural-sounding?"). Use `LLMJudgeReporter` (EvalKitJudge)
///   for those checks.
/// - When you only want to check item count, not vocabulary membership. Use `MaxWordsRule`
///   or `MaxSentencesRule` for length-based checks.
///
/// ## Usage example
///
/// ```swift
/// let allowedItems: [String: [String]] = [
///     "clothing": ["t-shirt", "jeans", "jacket", "socks"],
///     "toiletries": ["toothbrush", "shampoo", "sunscreen"]
/// ]
///
/// let rule = AllowedItemsRule(
///     allowedItems: allowedItems,
///     extractItems: { output in
///         // Parse the JSON output and return category → items
///         guard let data = output.data(using: .utf8),
///               let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
///         else { return [:] }
///         return json
///     }
/// )
/// ```
public struct AllowedItemsRule: EvaluationRule, Sendable {

    // MARK: - Properties

    /// The allowed vocabulary: category name → list of allowed items for that category.
    ///
    /// Each key is a category name that `extractItems` may return. Items extracted for a
    /// category that are not in its allowed list will be flagged as violations. Categories
    /// returned by `extractItems` but absent from `allowedItems` treat all items as
    /// disallowed (empty allowed set).
    public let allowedItems: [String: [String]]

    /// Closure that parses the model output and returns category → items found.
    ///
    /// This closure bridges raw model output to the structured form that the rule can check.
    /// It must be deterministic — same input, same output. If parsing fails (e.g. invalid JSON),
    /// return an empty dictionary, which will cause the rule to pass (no items to violate).
    /// If you prefer a parse failure to count as a violation, use `ValidJSONRule` alongside
    /// this rule to ensure the output is parseable before checking its contents.
    public let extractItems: @Sendable (String) -> [String: [String]]

    // MARK: - Init

    /// Create an allowed-items rule.
    ///
    /// - Parameters:
    ///   - allowedItems: The allowed vocabulary per category. Each key matches a category
    ///     name that `extractItems` may return.
    ///   - extractItems: Closure that parses the model output and returns a dictionary
    ///     mapping category names to the items found in that category. Items not in the
    ///     corresponding `allowedItems` entry will be flagged as violations.
    public init(
        allowedItems: [String: [String]],
        extractItems: @escaping @Sendable (String) -> [String: [String]]
    ) {
        self.allowedItems = allowedItems
        self.extractItems = extractItems
    }

    // MARK: - EvaluationRule

    public var name: String { "allowed_items" }

    public var failureMessage: String { "Output contains items not in the allowed list" }

    /// Evaluate whether all extracted items are in the allowed vocabulary.
    ///
    /// Calls `extractItems(output)` to parse the model output, then checks each item
    /// in each returned category against the `allowedItems` set for that category.
    ///
    /// - Returns: `true` if every item in every category is in the allowed list.
    ///   `false` if any single item is not in the allowed list for its category.
    public func evaluate(output: String, context: [String: String]) -> Bool {
        let extracted = extractItems(output)
        for (category, items) in extracted {
            let allowed = Set(allowedItems[category] ?? [])
            for item in items {
                if !allowed.contains(item) { return false }
            }
        }
        return true
    }

    /// Returns a detailed failure message listing all items not in the allowed list.
    public func failureDescription(for output: String, context: [String: String]) -> String {
        let extracted = extractItems(output)
        var violations: [String] = []
        for (category, items) in extracted.sorted(by: { $0.key < $1.key }) {
            let allowed = Set(allowedItems[category] ?? [])
            for item in items where !allowed.contains(item) {
                violations.append("\(item) (category: \(category))")
            }
        }
        return violations.isEmpty
            ? failureMessage
            : "Output contains items not in the allowed list: \(violations.joined(separator: ", "))"
    }
}
