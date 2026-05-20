// EvalKit — all processing is on-device. No data leaves the device.
//
// BLEUScore.swift
// EvalKitRetrieval/Metrics
//
// BLEU (Bilingual Evaluation Understudy) score for text generation evaluation.

import Foundation

/// Computes the BLEU score between a candidate text and one or more reference texts.
///
/// **What BLEU measures:**
/// BLEU counts how many word sequences (n-grams) in your generated text also appear
/// in the reference text. A score of 1.0 means identical. A score of 0.0 means no
/// overlap at any n-gram level.
///
/// Originally designed for machine translation evaluation, BLEU is widely used for
/// any text generation task where reference outputs exist.
///
/// **Worked example:**
/// ```
/// candidate:  "the cat sat on the mat"
/// reference:  "the cat is sitting on the mat"
///
/// Unigram (BLEU-1): "the","cat","on","the","mat" found → high overlap
/// Bigram  (BLEU-2): "the cat" found, "cat sat" not found in reference → lower overlap
/// ...
/// Combined BLEU-4 ≈ 0.45 (approximate, varies with brevity penalty)
/// ```
///
/// **Important limitations:**
/// - BLEU penalises valid paraphrases. Use it when exact wording matters
///   (e.g. translation). Do not use it as the only metric for creative generation.
/// - BLEU favours longer candidates at the n-gram level but penalises candidates
///   that are shorter than the reference via a brevity penalty.
/// - For evaluation of summaries or free-form generation, pair BLEU with `ROUGEScore`.
///
/// **Implementation:** Pure Swift, no external dependencies. Uses modified n-gram
/// precision with uniform weights and a brevity penalty (as in Papineni et al. 2002).
public enum BLEUScore {

    // MARK: - Compute

    /// Compute the BLEU-N score for a candidate string against reference strings.
    ///
    /// - Parameters:
    ///   - candidate: The generated text to evaluate.
    ///   - references: One or more reference texts. Multiple references allow
    ///     the metric to capture acceptable variation in the target output.
    ///   - maxNGram: The highest n-gram order to include. Defaults to `4` (BLEU-4).
    ///     Use `1` for BLEU-1 (unigram only).
    /// - Returns: A value in `[0.0, 1.0]`. Returns `0.0` for an empty candidate
    ///   or when all n-gram precisions are zero.
    public static func compute(
        candidate: String,
        references: [String],
        maxNGram: Int = 4
    ) -> Double {
        let candidateTokens = tokenise(candidate)
        guard !candidateTokens.isEmpty else { return 0.0 }
        guard !references.isEmpty else { return 0.0 }

        let referencesTokens = references.map { tokenise($0) }

        // Compute brevity penalty
        let bp = brevityPenalty(
            candidateLength: candidateTokens.count,
            referenceLengths: referencesTokens.map(\.count)
        )

        // Uniform weight for each n-gram level
        let weight = 1.0 / Double(maxNGram)

        var logSum = 0.0
        for n in 1...maxNGram {
            let precision = modifiedNGramPrecision(
                candidate: candidateTokens,
                references: referencesTokens,
                n: n
            )
            if precision <= 0.0 {
                return 0.0  // Any zero precision collapses BLEU to 0
            }
            logSum += weight * log(precision)
        }

        return bp * exp(logSum)
    }

    // MARK: - Private helpers

    private static func tokenise(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private static func ngrams(_ tokens: [String], n: Int) -> [String] {
        guard tokens.count >= n else { return [] }
        return (0...(tokens.count - n)).map { tokens[$0..<($0 + n)].joined(separator: " ") }
    }

    private static func ngramCounts(_ tokens: [String], n: Int) -> [String: Int] {
        var counts: [String: Int] = [:]
        for gram in ngrams(tokens, n: n) {
            counts[gram, default: 0] += 1
        }
        return counts
    }

    private static func modifiedNGramPrecision(
        candidate: [String],
        references: [[String]],
        n: Int
    ) -> Double {
        let candidateCounts = ngramCounts(candidate, n: n)
        guard !candidateCounts.isEmpty else { return 0.0 }

        // For each candidate n-gram, cap its count by the max count across any reference
        var clippedCount = 0
        for (gram, count) in candidateCounts {
            let maxRefCount = references
                .map { ngramCounts($0, n: n)[gram, default: 0] }
                .max() ?? 0
            clippedCount += min(count, maxRefCount)
        }

        let totalCandidateNGrams = candidateCounts.values.reduce(0, +)
        return totalCandidateNGrams > 0
            ? Double(clippedCount) / Double(totalCandidateNGrams)
            : 0.0
    }

    private static func brevityPenalty(candidateLength: Int, referenceLengths: [Int]) -> Double {
        guard !referenceLengths.isEmpty, candidateLength > 0 else { return 0.0 }
        // Use the reference length closest to the candidate length
        let closestRefLength = referenceLengths.min(by: {
            abs($0 - candidateLength) < abs($1 - candidateLength)
        }) ?? referenceLengths[0]
        if candidateLength >= closestRefLength { return 1.0 }
        return exp(1.0 - Double(closestRefLength) / Double(candidateLength))
    }
}
