// EvalKit — all processing is on-device. No data leaves the device.
//
// ROUGEScore.swift
// EvalKitRetrieval/Metrics
//
// ROUGE (Recall-Oriented Understudy for Gisting Evaluation) metrics for text generation.

import Foundation

/// Computes ROUGE scores between a candidate text and a reference text.
///
/// **What ROUGE measures:**
/// ROUGE measures overlap between generated and reference text, with emphasis on
/// **recall** — did the generation cover the reference content?
///
/// - **ROUGE-1**: Fraction of reference unigrams (words) that appear in the candidate.
///   Measures basic word overlap. Good for checking whether key terms are present.
/// - **ROUGE-2**: Fraction of reference bigrams (two-word sequences) that appear in
///   the candidate. More sensitive to phrase-level overlap and fluency.
/// - **ROUGE-L**: Based on the Longest Common Subsequence (LCS). Measures whether the
///   same sequence of ideas appears in both texts, even if individual words differ.
///   More robust to paraphrasing than ROUGE-1 or ROUGE-2.
///
/// **Note:** ROUGE-1 and ROUGE-2 measure word overlap. ROUGE-L measures whether the
/// same sequence of ideas appears in both texts, even if words differ.
///
/// **Worked example:**
/// ```
/// candidate: "the cat sat on the mat"
/// reference: "the cat is sitting on the mat"
///
/// ROUGE-1 recall: 5 reference unigrams found in candidate / 7 reference unigrams ≈ 0.71
/// ROUGE-2 recall: "the cat", "on the", "the mat" found / 6 reference bigrams = 0.50
/// ROUGE-L: LCS length = 5, reference length = 7 → 5/7 ≈ 0.71
/// ```
///
/// **Implementation:** Pure Swift, no external dependencies.
public enum ROUGEScore {

    // MARK: - Output

    /// The three ROUGE scores for a candidate/reference pair.
    public struct Output: Sendable {

        /// ROUGE-1: recall of unigrams (individual words).
        public let rouge1: Double

        /// ROUGE-2: recall of bigrams (two-word sequences).
        public let rouge2: Double

        /// ROUGE-L: longest common subsequence ratio.
        public let rougeL: Double
    }

    // MARK: - Compute

    /// Compute ROUGE-1, ROUGE-2, and ROUGE-L between a candidate and a reference string.
    ///
    /// - Parameters:
    ///   - candidate: The generated text to evaluate.
    ///   - reference: The ground-truth reference text.
    /// - Returns: `Output` with rouge1, rouge2, and rougeL values in `[0.0, 1.0]`.
    ///   Returns zeros when the reference is empty.
    public static func compute(candidate: String, reference: String) -> Output {
        let candidateTokens = tokenise(candidate)
        let referenceTokens = tokenise(reference)

        guard !referenceTokens.isEmpty else {
            return Output(rouge1: 0.0, rouge2: 0.0, rougeL: 0.0)
        }

        let r1 = recallNGram(candidate: candidateTokens, reference: referenceTokens, n: 1)
        let r2 = recallNGram(candidate: candidateTokens, reference: referenceTokens, n: 2)
        let rL = lcsRecall(candidate: candidateTokens, reference: referenceTokens)

        return Output(rouge1: r1, rouge2: r2, rougeL: rL)
    }

    // MARK: - Private helpers

    private static func tokenise(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private static func ngramCounts(_ tokens: [String], n: Int) -> [String: Int] {
        var counts: [String: Int] = [:]
        guard tokens.count >= n else { return counts }
        for i in 0...(tokens.count - n) {
            let gram = tokens[i..<(i + n)].joined(separator: " ")
            counts[gram, default: 0] += 1
        }
        return counts
    }

    /// Recall: |overlap n-grams| / |reference n-grams|
    private static func recallNGram(
        candidate: [String],
        reference: [String],
        n: Int
    ) -> Double {
        let refCounts = ngramCounts(reference, n: n)
        let totalRef = refCounts.values.reduce(0, +)
        guard totalRef > 0 else { return 0.0 }

        let candCounts = ngramCounts(candidate, n: n)
        var overlap = 0
        for (gram, refCount) in refCounts {
            let candCount = candCounts[gram, default: 0]
            overlap += min(candCount, refCount)
        }
        return Double(overlap) / Double(totalRef)
    }

    /// ROUGE-L: LCS-based recall
    private static func lcsRecall(candidate: [String], reference: [String]) -> Double {
        let lcsLen = lcsLength(candidate, reference)
        return reference.isEmpty ? 0.0 : Double(lcsLen) / Double(reference.count)
    }

    /// Dynamic programming longest common subsequence length.
    private static func lcsLength(_ a: [String], _ b: [String]) -> Int {
        let m = a.count, n = b.count
        guard m > 0, n > 0 else { return 0 }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = a[i - 1] == b[j - 1]
                    ? dp[i - 1][j - 1] + 1
                    : max(dp[i - 1][j], dp[i][j - 1])
            }
        }
        return dp[m][n]
    }
}
