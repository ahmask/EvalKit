// EvalKit — all processing is on-device. No data leaves the device.
//
// PositionSimilarity.swift
// EvalKitRetrieval/Metrics
//
// Measures how well the predicted ranked list matches the expected ranked list
// at each position.

import Foundation

/// Measures positional similarity between a predicted ranked list and the expected ranked list.
///
/// Position similarity counts how many items appear at the same position in both lists,
/// then divides by the length of the longer list:
///
/// **Formula:** score = matching positions / max(|predicted|, |expected|)
///
/// **Worked example:**
/// ```
/// predicted: ["topic1", "topic2", "topic3"]
/// expected:  ["topic1", "topic3", "topic2"]
///
/// Position 0: topic1 == topic1  ✓
/// Position 1: topic2 != topic3  ✗
/// Position 2: topic3 != topic2  ✗
///
/// matches = 1, max length = 3
/// PositionSimilarity = 1 / 3 ≈ 0.33
/// ```
///
/// **When to use:** Use position similarity when the rank order of results matters —
/// e.g. a search result list or a recommendation ranking where position 1 is most
/// important. Pair with `JaccardSimilarity` to capture both overlap and order quality.
public enum PositionSimilarity {

    // MARK: - Array overload

    /// Compute position similarity between two ordered arrays of strings.
    ///
    /// - Parameters:
    ///   - predicted: The model's predicted ranked list.
    ///   - expected: The ground-truth expected ranked list.
    /// - Returns: A value in `[0.0, 1.0]`. Returns `0.0` when both arrays are empty.
    public static func compute(predicted: [String], expected: [String]) -> Double {
        guard !predicted.isEmpty || !expected.isEmpty else { return 0.0 }
        let maxLen = max(predicted.count, expected.count)
        guard maxLen > 0 else { return 0.0 }
        var matches = 0
        let minLen = min(predicted.count, expected.count)
        for i in 0..<minLen {
            if predicted[i] == expected[i] { matches += 1 }
        }
        return Double(matches) / Double(maxLen)
    }

    // MARK: - String overload

    /// Compute position similarity between two comma-separated string lists.
    ///
    /// Splits each string on the given `separator`, trims whitespace, removes empty
    /// components, then delegates to the array overload.
    ///
    /// - Parameters:
    ///   - predicted: Comma-separated predicted items in ranked order.
    ///   - expected: Comma-separated expected items in ranked order.
    ///   - separator: The delimiter to split on. Defaults to `","`.
    /// - Returns: A value in `[0.0, 1.0]`.
    public static func compute(
        predicted: String,
        expected: String,
        separator: String = ","
    ) -> Double {
        let p = predicted.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let e = expected.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return compute(predicted: p, expected: e)
    }
}
