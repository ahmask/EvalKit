// EvalKit — all processing is on-device. No data leaves the device.
//
// RetrievalReporter.swift
// EvalKitRetrieval/Reporters
//
// EvaluationReporter that aggregates similarity scores from a retrieval evaluation run.

import Foundation
import EvalKit

/// A ready-to-use `EvaluationReporter` for retrieval and text similarity tasks.
///
/// ## Purpose
///
/// `RetrievalReporter` aggregates the `score` and `secondaryScore` fields from a
/// batch of `EvaluationResult` values produced by `SimilarityRunner`. It computes
/// mean, standard deviation, and P90 for each metric and checks whether the mean
/// primary score meets a configurable baseline threshold.
///
/// ## When to use
///
/// Use `RetrievalReporter` when your feature retrieves, ranks, or generates text
/// that is compared against a reference using a similarity metric — not exact match.
/// Typical cases:
/// - Topic retrieval: the model returns a set of topic tags, compared against expected topics
///   using Jaccard similarity.
/// - Search ranking: the model returns a ranked list, compared using position similarity and MRR.
/// - Text summarisation or generation: the model generates text, compared against a reference
///   using BLEU or ROUGE.
///
/// ## When not to use
///
/// - **Single-label classification with a correct answer**: Use `StandardClassificationReporter`.
///   When the model must return exactly one correct label, accuracy is the right metric,
///   not similarity.
/// - **Free-form generation quality**: If you are evaluating tone, fluency, or groundedness
///   rather than string overlap, use `LLMJudgeReporter` (EvalKitJudge). BLEU and ROUGE
///   penalise valid paraphrases and are not reliable proxies for quality.
///
/// ## Usage example
///
/// ```swift
/// // 1. Build your dataset
/// let cases = dataset.map { TextEvaluationCase(id: $0.id, input: $0.query, expectedOutput: $0.topicList) }
///
/// // 2. Run with SimilarityRunner
/// let runner = SimilarityRunner(primaryMetric: .jaccard(), secondaryMetric: .position()) { input in
///     let topics = try await topicModel.retrieve(input)
///     return topics.joined(separator: ",")
/// }
/// var results: [EvaluationResult] = []
/// for c in cases { results.append(try await runner.run(c)) }
///
/// // 3. Report
/// let reporter = RetrievalReporter(primaryMetric: .jaccard(), minimumMeanScore: 0.75)
/// let report = reporter.report(from: results, featureName: "TopicFinder")
///
/// print(report.passedBaseline)             // true / false
/// print(report.metrics.scoreMean ?? 0)     // e.g. 0.82 mean Jaccard
/// print(report.metrics.scoreP90 ?? 0)      // e.g. 0.95
/// print(report.metrics.secondaryScoreMean ?? 0)  // e.g. 0.71 mean position
/// ```
public struct RetrievalReporter: EvaluationReporter, Sendable {

    // MARK: - Properties

    /// The primary similarity metric used by `SimilarityRunner`.
    ///
    /// Used only for the `baselineDescription` string in the report (e.g. `"mean jaccard >= 0.75"`).
    /// This value must match the `primaryMetric` passed to `SimilarityRunner` so the
    /// description is accurate. It does not affect any metric calculations.
    public let primaryMetric: SimilarityMetric

    /// Minimum mean primary score required for `passedBaseline` to be `true`.
    ///
    /// When the mean of all `EvaluationResult.score` values falls below this threshold,
    /// `report.passedBaseline` is `false`. Defaults to `0.75`. Set higher (e.g. `0.90`)
    /// for features where near-exact retrieval is required.
    public let minimumMeanScore: Double

    // MARK: - Init

    /// Create a retrieval reporter.
    ///
    /// - Parameters:
    ///   - primaryMetric: The similarity metric used to generate the `score` field in results.
    ///     Must match the `primaryMetric` used in `SimilarityRunner`. Used only in the
    ///     baseline description string, not in metric calculations.
    ///   - minimumMeanScore: Mean score threshold below which `passedBaseline` is `false`.
    ///     Defaults to `0.75`.
    public init(primaryMetric: SimilarityMetric, minimumMeanScore: Double = 0.75) {
        self.primaryMetric = primaryMetric
        self.minimumMeanScore = minimumMeanScore
    }

    // MARK: - EvaluationReporter

    /// Build a full evaluation report from a batch of retrieval results.
    ///
    /// Aggregates mean, standard deviation, and P90 for `score` and `secondaryScore`.
    /// Sets `passedBaseline` when mean `score` meets or exceeds `minimumMeanScore`.
    ///
    /// - Parameters:
    ///   - results: Per-case results from `SimilarityRunner`. Results with `nil` score
    ///     are excluded from similarity metric calculations but counted in `totalCases`.
    ///   - featureName: Human-readable feature name used in the report.
    /// - Returns: A complete `EvaluationReport` with `scoreMean`, `scoreStd`, `scoreP90`,
    ///   and optionally `secondaryScoreMean`, `secondaryScoreStd`, `secondaryScoreP90`
    ///   in `metrics`. Fields are `nil` when no results carry a score.
    public func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
        let scores          = results.compactMap(\.score)
        let secondaryScores = results.compactMap(\.secondaryScore)
        let latencies       = results.map(\.latencyMs)

        let scoreMean      = P90Calculator.mean(scores)
        let scoreStd       = P90Calculator.standardDeviation(scores)
        let scoreP90       = P90Calculator.p90(scores)

        let secondaryMean  = secondaryScores.isEmpty ? nil : P90Calculator.mean(secondaryScores)
        let secondaryStd   = secondaryScores.isEmpty ? nil : P90Calculator.standardDeviation(secondaryScores)
        let secondaryP90   = secondaryScores.isEmpty ? nil : P90Calculator.p90(secondaryScores)

        let passRate = results.isEmpty
            ? 0.0
            : Double(results.filter(\.isCorrect).count) / Double(results.count)

        let metrics = EvaluationMetrics(
            totalCases:          results.count,
            passRate:            passRate,
            errorCount:          results.filter { $0.error != nil }.count,
            latencyMsMean:       P90Calculator.mean(latencies),
            latencyMsP90:        P90Calculator.p90(latencies),
            scoreMean:           scores.isEmpty ? nil : scoreMean,
            scoreStd:            scores.isEmpty ? nil : scoreStd,
            scoreP90:            scores.isEmpty ? nil : scoreP90,
            secondaryScoreMean:  secondaryMean,
            secondaryScoreStd:   secondaryStd,
            secondaryScoreP90:   secondaryP90
        )

        return EvaluationReport(
            featureName:         featureName,
            metrics:             metrics,
            results:             results,
            passedBaseline:      scoreMean >= minimumMeanScore,
            baselineDescription: "mean \(primaryMetric.name) >= \(minimumMeanScore)"
        )
    }
}
