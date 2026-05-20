// EvalKit — all processing is on-device. No data leaves the device.
//
// JaccardSimilarity.swift
// EvalKitRetrieval/Metrics
//
// Computes the Jaccard similarity coefficient between two sets of strings.

import Foundation

/// Computes the Jaccard similarity coefficient between two sets of string items.
///
/// Jaccard similarity measures overlap between two sets as the ratio of their
/// intersection size to their union size:
///
/// **Formula:** J(A, B) = |A ∩ B| / |A ∪ B|
///
/// **Worked example:**
/// ```
/// predicted: ["topic1", "topic2", "topic3"]
/// expected:  ["topic1", "topic2", "topic4"]
///
/// intersection: ["topic1", "topic2"]          count = 2
/// union:        ["topic1", "topic2", "topic3", "topic4"]  count = 4
///
/// Jaccard = 2 / 4 = 0.5
/// ```
///
/// A score of `1.0` means the two sets are identical. A score of `0.0` means they
/// share no common elements (or both are empty).
///
/// **When to use:** Use Jaccard for retrieval tasks where order does not matter —
/// e.g. topic tags, category sets, retrieved document IDs. For tasks where order
/// matters, see `PositionSimilarity`. For text quality, see `BLEUScore` or `ROUGEScore`.
public enum JaccardSimilarity {

    // MARK: - Array overload

    /// Compute the Jaccard similarity between two arrays of strings.
    ///
    /// Duplicate items within an array are ignored (sets are used internally).
    ///
    /// - Parameters:
    ///   - predicted: The model's predicted items.
    ///   - expected: The ground-truth expected items.
    /// - Returns: A value in `[0.0, 1.0]`. Returns `0.0` when both arrays are empty.
    public static func compute(predicted: [String], expected: [String]) -> Double {
        let p = Set(predicted)
        let e = Set(expected)
        guard !p.isEmpty || !e.isEmpty else { return 0.0 }
        let intersection = p.intersection(e).count
        let union = p.union(e).count
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }

    // MARK: - String overload

    /// Compute the Jaccard similarity between two comma-separated string lists.
    ///
    /// Splits each string on the given `separator`, trims whitespace, removes empty
    /// components, then delegates to the array overload.
    ///
    /// - Parameters:
    ///   - predicted: Comma-separated predicted items (e.g. `"topic1,topic2,topic3"`).
    ///   - expected: Comma-separated expected items (e.g. `"topic1,topic2,topic4"`).
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
