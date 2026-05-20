// EvalKit — all processing is on-device. No data leaves the device.
//
// SimilarityRunner.swift
// EvalKitRetrieval/Runners
//
// EvaluationRunner that measures similarity between predicted and expected text
// using a configurable similarity metric.

import Foundation
import EvalKit

// MARK: - SimilarityMetric

/// The similarity metric used to compare predicted output against expected output.
///
/// ## Purpose
///
/// `SimilarityMetric` selects the algorithm that `SimilarityRunner` uses to score
/// a model prediction against its expected reference. The choice of metric determines
/// what "good" means for your feature — exact set overlap, position match, word-level
/// precision, or recall-oriented text overlap.
///
/// ## When to use each case
///
/// - **`.jaccard`**: Use for unordered label sets or topic tags where only membership
///   matters (e.g. topic retrieval). `"topic1,topic2,topic3"` vs `"topic1,topic2,topic4"`.
///
/// - **`.position`**: Use for ranked lists where both membership and order matter
///   (e.g. search result ranking). Penalises items in the wrong position even if
///   they are present.
///
/// - **`.bleu`**: Use for text generation tasks where exact n-gram precision against a
///   reference matters (e.g. translation, templated output generation).
///
/// - **`.rouge1`**: Use for summarisation where basic word coverage matters. Checks
///   whether key words from the reference appear in the candidate.
///
/// - **`.rouge2`**: Use for summarisation where phrase-level overlap matters. More
///   sensitive than ROUGE-1 to fluency and phrasing.
///
/// - **`.rougeL`**: Use for summarisation where sequence-level overlap matters.
///   Robust to paraphrasing — counts longest common subsequences rather than exact phrases.
///
/// ## When not to use
///
/// Similarity metrics measure string overlap, not semantic quality. They penalise
/// valid paraphrases. If your feature generates free-form text where any well-written
/// response is acceptable (greeting generation, RAG answers), use `LLMJudgeReporter`
/// (EvalKitJudge) for quality assessment instead.
public enum SimilarityMetric: Sendable {

    /// Jaccard set similarity. Splits predicted and expected by `separator` before computing.
    ///
    /// Score = |intersection| / |union|. `1.0` = identical sets. `0.0` = no overlap.
    /// Use for topic tags, category sets, and any retrieval where order does not matter.
    case jaccard(separator: String = ",")

    /// Positional match similarity. Splits predicted and expected by `separator`.
    ///
    /// Score = matching positions / max(|predicted|, |expected|). Penalises items at
    /// wrong positions. Use for ranked lists where position 1 matters most.
    case position(separator: String = ",")

    /// BLEU score with n-gram order up to `maxNGram` (default 4 = BLEU-4).
    ///
    /// Measures n-gram precision with a brevity penalty. Use for translation,
    /// or any generation task where exact phrasing against a reference is meaningful.
    case bleu(maxNGram: Int = 4)

    /// ROUGE-1 unigram recall.
    ///
    /// Fraction of reference unigrams that appear in the candidate.
    /// Use for summarisation — checks whether key words are present.
    case rouge1

    /// ROUGE-2 bigram recall.
    ///
    /// Fraction of reference bigrams that appear in the candidate.
    /// More sensitive than ROUGE-1 to phrase-level overlap and fluency.
    case rouge2

    /// ROUGE-L longest common subsequence recall.
    ///
    /// Measures whether the same sequence of ideas appears in both texts,
    /// even if individual words differ. More robust to paraphrasing than ROUGE-1/2.
    case rougeL

    /// Human-readable name for this metric, used in baseline description strings.
    ///
    /// Examples: `"jaccard"`, `"position"`, `"bleu4"`, `"rouge1"`.
    public var name: String {
        switch self {
        case .jaccard:          return "jaccard"
        case .position:         return "position"
        case .bleu(let n):      return "bleu\(n)"
        case .rouge1:           return "rouge1"
        case .rouge2:           return "rouge2"
        case .rougeL:           return "rougeL"
        }
    }

    /// Compute the similarity score between a predicted string and an expected string.
    ///
    /// Delegates to the appropriate metric implementation. Returns a value in `[0.0, 1.0]`.
    ///
    /// - Parameters:
    ///   - predicted: The model's output string.
    ///   - expected: The ground-truth reference string.
    /// - Returns: Similarity score in `[0.0, 1.0]`.
    public func score(predicted: String, expected: String) -> Double {
        switch self {
        case .jaccard(let sep):
            return JaccardSimilarity.compute(predicted: predicted, expected: expected, separator: sep)
        case .position(let sep):
            return PositionSimilarity.compute(predicted: predicted, expected: expected, separator: sep)
        case .bleu(let maxN):
            return BLEUScore.compute(candidate: predicted, references: [expected], maxNGram: maxN)
        case .rouge1:
            return ROUGEScore.compute(candidate: predicted, reference: expected).rouge1
        case .rouge2:
            return ROUGEScore.compute(candidate: predicted, reference: expected).rouge2
        case .rougeL:
            return ROUGEScore.compute(candidate: predicted, reference: expected).rougeL
        }
    }

    /// Whether this metric uses exact-match semantics (Jaccard/position) or soft-match (BLEU/ROUGE).
    ///
    /// Exact-match metrics treat `score >= 1.0` as a pass (the sets/order must match perfectly).
    /// Soft-match metrics use a configurable `passingThreshold` (default 0.8) instead.
    /// This distinction is used by `SimilarityRunner` to set `EvaluationResult.isCorrect`.
    var isExactMatchMetric: Bool {
        switch self {
        case .jaccard, .position: return true
        case .bleu, .rouge1, .rouge2, .rougeL: return false
        }
    }
}

// MARK: - SimilarityRunner

/// An `EvaluationRunner` that evaluates text similarity between predicted and expected output.
///
/// ## Purpose
///
/// `SimilarityRunner` calls a `predict` closure with the test case input, then computes
/// similarity scores between the prediction and the expected output using the configured
/// `SimilarityMetric`. It returns a standard `EvaluationResult` with `score` and
/// optionally `secondaryScore` populated for downstream `RetrievalReporter` aggregation.
///
/// ## When to use
///
/// Use `SimilarityRunner` for any feature where the model returns text that should be
/// compared against a reference, and a perfect exact match is not required or not possible:
/// - Topic retrieval: the model returns comma-separated topics compared against expected topics.
/// - RAG topic finding: the model returns a ranked topic list compared with Jaccard + position.
/// - Summarisation quality (approximate): BLEU or ROUGE against reference summaries.
///
/// ## When not to use
///
/// - **Single-label classification**: If your model returns exactly one label that must
///   match exactly, use a classification runner with `StandardClassificationReporter`.
///   `SimilarityRunner` with Jaccard on single labels works but adds unnecessary indirection.
/// - **Generation quality**: BLEU/ROUGE penalise valid paraphrases. For tone, fluency,
///   and groundedness, use `LLMJudgeReporter` (EvalKitJudge) instead.
///
/// ## isCorrect semantics
///
/// - For Jaccard and position metrics: `isCorrect = score >= 1.0` (exact match only).
/// - For BLEU and ROUGE metrics: `isCorrect = score >= passingThreshold` (default 0.8).
///   Override `passingThreshold` in the initialiser for a different cutoff.
///
/// ## Usage example
///
/// ```swift
/// let runner = SimilarityRunner(
///     primaryMetric: .jaccard(),
///     secondaryMetric: .position()
/// ) { input in
///     let topics = try await topicModel.retrieve(input)
///     return topics.joined(separator: ",")
/// }
///
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// let reporter = RetrievalReporter(primaryMetric: .jaccard(), minimumMeanScore: 0.75)
/// let report = reporter.report(from: results, featureName: "TopicFinder")
/// ```
public struct SimilarityRunner: EvaluationRunner, Sendable {

    // MARK: - Types

    public typealias Case = TextEvaluationCase

    // MARK: - Properties

    private let primaryMetric: SimilarityMetric
    private let secondaryMetric: SimilarityMetric?
    private let passingThreshold: Double
    private let predict: @Sendable (String) async throws -> String

    // MARK: - Init

    /// Create a similarity runner.
    ///
    /// - Parameters:
    ///   - primaryMetric: The metric used to populate `EvaluationResult.score` and
    ///     determine `isCorrect`. This metric drives the baseline gate in `RetrievalReporter`.
    ///   - secondaryMetric: Optional additional metric for `EvaluationResult.secondaryScore`.
    ///     Use to capture a complementary signal alongside the primary (e.g. position
    ///     alongside Jaccard). Pass `nil` to skip secondary scoring.
    ///   - passingThreshold: Score at or above which `isCorrect` is `true` for BLEU/ROUGE
    ///     metrics. Ignored for Jaccard/position, which use exact-match semantics (`score >= 1.0`).
    ///     Defaults to `0.8`. Lower this if your reference texts allow for significant variation.
    ///   - predict: Closure that calls the model under evaluation with the case input string
    ///     and returns the model's output string. For multi-label outputs, join items with
    ///     the same separator your metric expects (default `","`).
    public init(
        primaryMetric: SimilarityMetric,
        secondaryMetric: SimilarityMetric? = nil,
        passingThreshold: Double = 0.8,
        predict: @escaping @Sendable (String) async throws -> String
    ) {
        self.primaryMetric = primaryMetric
        self.secondaryMetric = secondaryMetric
        self.passingThreshold = passingThreshold
        self.predict = predict
    }

    // MARK: - EvaluationRunner

    /// Run a single test case, compute similarity scores, and return a result.
    ///
    /// Calls `predict` with `testCase.input`, measures latency, computes primary and
    /// optionally secondary similarity scores against `testCase.expectedOutput`, and
    /// sets `isCorrect` based on the primary score and the metric's pass semantics.
    ///
    /// Never throws — errors from `predict` are captured in `EvaluationResult.error`
    /// with `isCorrect = false`, so a single failure does not abort the batch.
    ///
    /// - Parameter testCase: The case to evaluate. `testCase.expectedOutput` must be
    ///   a string in the format the configured metric expects (e.g. comma-separated
    ///   for Jaccard/position, plain text for BLEU/ROUGE).
    /// - Returns: An `EvaluationResult` with `score`, optionally `secondaryScore`,
    ///   `isCorrect`, `latencyMs`, and `error` populated.
    public func run(_ testCase: TextEvaluationCase) async throws -> EvaluationResult {
        var latencyMs: Double = 0
        do {
            let predicted = try await LatencyMeasurer.measure(into: &latencyMs) {
                try await predict(testCase.input)
            }
            let primaryScore = primaryMetric.score(predicted: predicted, expected: testCase.expectedOutput)
            let secondaryScore = secondaryMetric?.score(predicted: predicted, expected: testCase.expectedOutput)

            let isCorrect: Bool
            if primaryMetric.isExactMatchMetric {
                isCorrect = primaryScore >= 1.0
            } else {
                isCorrect = primaryScore >= passingThreshold
            }

            return EvaluationResult(
                id: testCase.id,
                isCorrect: isCorrect,
                latencyMs: latencyMs,
                predictedLabel: predicted,
                expectedLabel: testCase.expectedOutput,
                score: primaryScore,
                secondaryScore: secondaryScore
            )
        } catch {
            return EvaluationResult(
                id: testCase.id,
                isCorrect: false,
                latencyMs: latencyMs,
                predictedLabel: nil,
                expectedLabel: testCase.expectedOutput,
                error: error.localizedDescription
            )
        }
    }
}
