// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeScore.swift
// EvalKitJudge/Models
//
// The judge's evaluation of a single quality dimension for one test case.

import Foundation

/// The judge's evaluation of a single quality dimension for one test case.
///
/// ## Purpose
///
/// `JudgeScore` holds the result of one judge LLM call for one dimension on one test case.
/// It records the numeric score, the judge's reasoning, the passing threshold, and
/// (for item-by-item dimensions) the per-fact breakdown.
///
/// ## When to use
///
/// Access `JudgeScore` values from `JudgeResult.scores`. Use `JudgeResult.score(for:)`
/// to look up a specific dimension, or iterate `scores` for all dimensions. Use `passed`
/// to quickly check whether this dimension met its threshold for this case.
///
/// ## Score interpretation
///
/// | Scoring pattern | `score` range | Meaning |
/// |---|---|---|
/// | Binary | `0.0` or `1.0` | `0.0` = failed, `1.0` = passed |
/// | Holistic | `1.0` to `5.0` | `5.0` = best, `1.0` = worst |
/// | Item-by-item | `0.0` to `1.0` | Fraction of key facts present |
///
/// Note: `JudgeMetrics` normalises holistic scores to `[0.0, 1.0]` for aggregation.
/// `JudgeScore.score` is the raw value returned by the judge.
public struct JudgeScore: Sendable {

    // MARK: - Nested Types

    /// The judge's verdict on one individual key fact (item-by-item dimensions only).
    ///
    /// Contains the fact text, whether it was found (1) or missing (0), and the judge's
    /// reasoning for that verdict. Access per-fact scores via `JudgeScore.factScores`.
    public struct FactScore: Sendable {

        /// The key fact text that was evaluated.
        ///
        /// Matches one entry from the `keyFacts` array provided at evaluation time via
        /// `keyFactsOverride` in `LLMJudgeRunner`. Used as the key in per-fact reporting.
        public let fact: String

        /// Whether this fact was found (`1`) or missing (`0`) in the model output.
        ///
        /// `1` = the fact is present in or can be inferred from the model output, even
        /// if the wording differs. `0` = the fact is absent or only partly present.
        public let score: Int

        /// The judge's reasoning for this verdict on this specific fact.
        ///
        /// Describes what the judge looked for and why it determined the fact was
        /// present or absent. Use for debugging unexpected 0-scores.
        public let reasoning: String

        /// Create a fact-level score.
        ///
        /// - Parameters:
        ///   - fact: The key fact text that was evaluated.
        ///   - score: `1` if found/inferable, `0` if missing/partial.
        ///   - reasoning: The judge's explanation for this verdict.
        public init(fact: String, score: Int, reasoning: String) {
            self.fact = fact
            self.score = score
            self.reasoning = reasoning
        }
    }

    // MARK: - Properties

    /// The dimension name (e.g. `"fluency"`, `"tone"`, `"recall"`).
    ///
    /// Matches `JudgeDimension.name`. Used as the key in `JudgeResult.score(for:)`.
    public let dimension: String

    /// The numeric score for this dimension.
    ///
    /// - **Binary**: `1.0` = passed (grammatically correct, no issues), `0.0` = failed.
    /// - **Holistic**: `1.0` (worst) to `5.0` (best). `3.0` is the default passing threshold.
    /// - **Item-by-item**: `0.0` to `1.0` — the fraction of key facts found (e.g. `0.75` = 3/4).
    ///
    /// Note: `JudgeMetrics` normalises holistic scores to `[0.0, 1.0]` for comparison.
    /// This property stores the raw value as returned by the judge.
    public let score: Double

    /// The judge's overall reasoning or summary for this dimension and test case.
    ///
    /// For holistic and binary dimensions, explains why the given score was awarded.
    /// For item-by-item dimensions, contains a summary; per-fact reasoning is in `factScores`.
    public let reasoning: String

    /// Minimum score at or above which this dimension is considered passing.
    ///
    /// - Binary: always `1.0` (must pass exactly).
    /// - Holistic: configurable in `LLMJudgeRunner` (default `3.0` — "acceptable quality").
    /// - Item-by-item: configurable in `LLMJudgeRunner` (default `0.75` — 75% of facts present).
    public let passingThreshold: Double

    /// Per-fact scores for item-by-item dimensions.
    ///
    /// Empty for holistic and binary dimensions. Contains one `FactScore` per key fact
    /// provided at evaluation time. Use to identify which specific facts are most often
    /// missed across the dataset by aggregating `factPassRates` in `JudgeMetrics.DimensionMetrics`.
    public let factScores: [FactScore]

    // MARK: - Computed

    /// `true` if this dimension's `score` meets or exceeds `passingThreshold`.
    ///
    /// The test a case uses for `JudgeResult.allPassed`. When `false`, this dimension
    /// caused this case to fail.
    public var passed: Bool { score >= passingThreshold }

    // MARK: - Init

    /// Create a judge score.
    ///
    /// - Parameters:
    ///   - dimension: The dimension name (must match `JudgeDimension.name`).
    ///   - score: Numeric score — `1.0`/`0.0` for binary, `1`–`5` for holistic, `0`–`1` for item-by-item.
    ///   - reasoning: Overall reasoning or summary from the judge LLM.
    ///   - passingThreshold: Minimum score required for `passed` to be `true`.
    ///   - factScores: Per-fact results (only for item-by-item dimensions). Defaults to `[]`.
    public init(
        dimension: String,
        score: Double,
        reasoning: String,
        passingThreshold: Double,
        factScores: [FactScore] = []
    ) {
        self.dimension = dimension
        self.score = score
        self.reasoning = reasoning
        self.passingThreshold = passingThreshold
        self.factScores = factScores
    }
}
