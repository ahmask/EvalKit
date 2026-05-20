// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeMetrics.swift
// EvalKitJudge/Models
//
// Aggregated metrics computed from a batch of JudgeResult values.

import Foundation
import EvalKit

/// Aggregated metrics computed from a batch of `JudgeResult` values.
///
/// ## Purpose
///
/// `JudgeMetrics` is the aggregate statistics container for a judge evaluation run.
/// It holds overall pass rate, latency statistics, and per-dimension breakdowns.
/// `JudgeReport.metrics` contains a `JudgeMetrics` value that summarises the full batch.
///
/// ## When to use
///
/// Read `JudgeMetrics` from `JudgeReport.metrics` after calling
/// `LLMJudgeReporter.report(from:featureName:outputProvider:keyFactsProvider:)`.
/// Use it to compare quality across model versions, find which dimensions are failing,
/// and gate CI pipelines on per-dimension pass rates.
///
/// ## When not to use
///
/// `JudgeMetrics.compute(from:...)` is called internally by `LLMJudgeReporter` — you
/// do not need to call it directly. Read the pre-computed metrics from `JudgeReport`.
public struct JudgeMetrics: Sendable {

    // MARK: - Nested Types

    /// Aggregated metrics for a single quality dimension across all evaluated cases.
    ///
    /// One `DimensionMetrics` value is produced per unique dimension name in the batch.
    /// Access the full list via `JudgeMetrics.dimensionMetrics`.
    public struct DimensionMetrics: Sendable {

        /// The dimension name, matching `JudgeDimension.name`.
        ///
        /// Examples: `"fluency"`, `"tone"`, `"recall"`. Use this key to look up a
        /// specific dimension when iterating `JudgeMetrics.dimensionMetrics`.
        public let dimension: String

        /// The scoring pattern used by this dimension.
        ///
        /// Indicates whether scores are binary (0/1), holistic (1–5 normalised to 0–1),
        /// or item-by-item (ratio of facts passed). Use to interpret `averageScore` and
        /// `p90Score` correctly — a `0.8` average means different things per pattern.
        public let scoringPattern: JudgeScoringPattern

        /// Mean score across all cases for this dimension. In `[0.0, 1.0]`.
        ///
        /// `1.0` = every case passed this dimension at the maximum score.
        /// `0.0` = every case scored 0 on this dimension.
        /// For holistic dimensions, scores are normalised from 1–5 to `[0.0, 1.0]`
        /// before averaging (i.e. score 5 → 1.0, score 1 → 0.0).
        public let averageScore: Double

        /// Fraction of cases where this dimension's score met its passing threshold.
        /// In `[0.0, 1.0]`.
        ///
        /// The threshold is `1.0` for binary dimensions, `passingThreshold` for holistic,
        /// and `itemByItemPassingThreshold` for item-by-item.
        /// `1.0` = every case passed. `0.0` = no case passed.
        public let passRate: Double

        /// 90th-percentile score across all cases for this dimension. In `[0.0, 1.0]`.
        ///
        /// Higher is better — indicates the score floor for the best 90% of cases.
        /// A low P90 (e.g. 0.6) with a high average (e.g. 0.85) indicates a minority of
        /// cases are dragging the dimension down severely.
        public let p90Score: Double

        /// Per-fact pass rates across all cases. Only populated for item-by-item dimensions.
        ///
        /// Maps each key fact string to the fraction of cases in which that fact was found
        /// (score = 1). Empty for holistic and binary dimensions. Use to identify which
        /// specific facts the model most often misses across the dataset.
        public let factPassRates: [String: Double]
    }

    // MARK: - Properties

    /// Total number of evaluated test cases in this judge run.
    public let totalCases: Int

    /// Fraction of cases where every dimension passed (`JudgeResult.allPassed == true`). In `[0.0, 1.0]`.
    ///
    /// `1.0` = all cases passed all dimensions. `0.0` = no case passed all dimensions.
    /// A case counts as "passed" only if ALL its evaluated dimensions meet their respective thresholds.
    public let passRate: Double

    /// Number of cases where `JudgeResult.error` is non-nil.
    ///
    /// Errors are captured without aborting the batch. A high error count may indicate
    /// the judge LLM is not responding with valid JSON or the `outputProvider` is failing.
    public let errorCount: Int

    /// Mean end-to-end latency per case across all cases in milliseconds.
    ///
    /// Includes the time for calling `outputProvider` and all `LLMJudgeRunner.evaluate`
    /// calls (one per dimension per case). Higher latency indicates the judge LLM is slow.
    public let latencyMsMean: Double

    /// 90th-percentile end-to-end latency across all cases in milliseconds.
    ///
    /// The 90th percentile captures tail latency — the slowest 10% of cases.
    /// Use to assess worst-case evaluation time for CI pipeline planning.
    public let latencyMsP90: Double

    /// Per-dimension aggregated metrics, one entry per unique dimension in the batch.
    ///
    /// Ordered by first occurrence in the batch. Inspect individual `DimensionMetrics`
    /// to find which dimension has the lowest pass rate or highest tail latency.
    public let dimensionMetrics: [DimensionMetrics]

    // MARK: - Factory

    /// Compute aggregated metrics from a batch of judge results.
    ///
    /// Called internally by `LLMJudgeReporter`. You do not need to call this directly —
    /// read metrics from `JudgeReport.metrics` instead.
    ///
    /// - Parameters:
    ///   - results: The raw per-case `JudgeResult` values from `LLMJudgeRunner`.
    ///   - passingThreshold: Normalised score `[0.0, 1.0]` at or above which a holistic
    ///     dimension is considered passing.
    ///   - itemByItemPassingThreshold: Ratio `[0.0, 1.0]` at or above which an item-by-item
    ///     dimension is considered passing (e.g. `0.8` = 80% of facts must be present).
    /// - Returns: A fully populated `JudgeMetrics` value.
    public static func compute(
        from results: [JudgeResult],
        passingThreshold: Double,
        itemByItemPassingThreshold: Double
    ) -> JudgeMetrics {
        let total = results.count
        let passedCount = results.filter(\.allPassed).count
        let passRate = total > 0 ? Double(passedCount) / Double(total) : 0.0
        let errorCount = results.filter { $0.error != nil }.count
        let latencies = results.map(\.latencyMs)
        let latencyMean = P90Calculator.mean(latencies)
        let latencyP90 = P90Calculator.p90(latencies)

        // Gather all unique dimension names preserving insertion order
        var dimensionNames: [String] = []
        var seenNames = Set<String>()
        for result in results {
            for score in result.scores {
                if seenNames.insert(score.dimension).inserted {
                    dimensionNames.append(score.dimension)
                }
            }
        }

        var dimMetrics: [DimensionMetrics] = []

        for dimName in dimensionNames {
            let dimScores = results.compactMap { $0.score(for: dimName) }
            guard let firstScore = dimScores.first else { continue }

            let pattern: JudgeScoringPattern = firstScore.factScores.isEmpty
                ? (firstScore.passingThreshold == 1.0 ? .binary : .holistic)
                : .itemByItem(keyFacts: [])

            let threshold: Double
            switch pattern {
            case .binary:         threshold = 1.0
            case .holistic:       threshold = passingThreshold
            case .itemByItem:     threshold = itemByItemPassingThreshold
            }

            let scoreValues = dimScores.map(\.score)
            let avg = P90Calculator.mean(scoreValues)
            let p90 = P90Calculator.p90(scoreValues)
            let passedDim = dimScores.filter { $0.score >= threshold }.count
            let dimPassRate = total > 0 ? Double(passedDim) / Double(total) : 0.0

            // Compute per-fact pass rates for item-by-item dimensions
            var factPassRates: [String: Double] = [:]
            if case .itemByItem = pattern {
                var factOccurrences: [String: Int] = [:]
                var factHits: [String: Int] = [:]
                for judgeScore in dimScores {
                    for fs in judgeScore.factScores {
                        factOccurrences[fs.fact, default: 0] += 1
                        factHits[fs.fact, default: 0] += fs.score
                    }
                }
                for (fact, count) in factOccurrences {
                    factPassRates[fact] = Double(factHits[fact, default: 0]) / Double(count)
                }
            }

            dimMetrics.append(DimensionMetrics(
                dimension: dimName,
                scoringPattern: pattern,
                averageScore: avg,
                passRate: dimPassRate,
                p90Score: p90,
                factPassRates: factPassRates
            ))
        }

        return JudgeMetrics(
            totalCases: total,
            passRate: passRate,
            errorCount: errorCount,
            latencyMsMean: latencyMean,
            latencyMsP90: latencyP90,
            dimensionMetrics: dimMetrics
        )
    }
}
