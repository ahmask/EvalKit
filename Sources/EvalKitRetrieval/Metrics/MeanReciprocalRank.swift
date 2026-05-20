// EvalKit — all processing is on-device. No data leaves the device.
//
// MeanReciprocalRank.swift
// EvalKitRetrieval/Metrics
//
// Computes Mean Reciprocal Rank (MRR) — a standard metric for ranked retrieval evaluation.

import Foundation

/// Computes Mean Reciprocal Rank (MRR) for a set of ranked retrieval results.
///
/// **Plain-language explanation:**
/// Imagine you search for something 10 times. MRR measures on average how far down
/// the list you had to scroll before finding a correct answer. An MRR of 1.0 means
/// the correct answer was always first. An MRR of 0.5 means it was on average second.
///
/// **Formula:**
/// ```
/// MRR = (1 / N) × Σ (1 / rank_of_first_relevant_item)
/// ```
/// where rank is 1-based. If no relevant item appears in a result list, that query
/// contributes 0 to the sum.
///
/// **Worked example:**
/// ```
/// Query 1 result list: ["topic3", "topic1", "topic2"]
///   relevant: ["topic1"]  →  first relevant at position 2  →  1/2 = 0.5
///
/// Query 2 result list: ["topic1", "topic2", "topic3"]
///   relevant: ["topic1"]  →  first relevant at position 1  →  1/1 = 1.0
///
/// MRR = (0.5 + 1.0) / 2 = 0.75
/// ```
///
/// **When to use:** MRR is appropriate when the user cares primarily about finding
/// at least one correct answer, and wants it as high in the list as possible.
/// Use it for question answering, search, or any ranked retrieval scenario.
public enum MeanReciprocalRank {

    // MARK: - Compute

    /// Compute Mean Reciprocal Rank over multiple result lists.
    ///
    /// - Parameters:
    ///   - results: A list of ranked result lists. Each inner array is the ranked
    ///     output for one query, with the most relevant item expected first.
    ///   - relevant: The set of items considered relevant (correct answers).
    ///     Any item in this set counts as a relevant hit.
    /// - Returns: MRR in `[0.0, 1.0]`. Returns `0.0` if `results` is empty or
    ///   no relevant item appears in any result list.
    public static func compute(results: [[String]], relevant: [String]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        let relevantSet = Set(relevant)
        var reciprocalRankSum = 0.0

        for resultList in results {
            for (index, item) in resultList.enumerated() {
                if relevantSet.contains(item) {
                    // rank is 1-based
                    reciprocalRankSum += 1.0 / Double(index + 1)
                    break
                }
            }
            // If no relevant item found, reciprocal rank is 0 — nothing added
        }

        return reciprocalRankSum / Double(results.count)
    }
}
