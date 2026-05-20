// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationResult.swift
// EvalKit/Models
//
// Raw per-case result produced by an EvaluationRunner.
// Fields cover what the existing on-device projects compute: classification,
// similarity scoring (Jaccard / position), and LLM format validation.

import Foundation

/// Raw outcome for a single evaluation test case.
///
/// ## Purpose
///
/// `EvaluationResult` is the universal result type returned by every `EvaluationRunner`.
/// It stores the pass/fail verdict, latency, and all feature-specific metric fields
/// in one flat struct. Fields that do not apply to a given feature are left `nil` or
/// at their default value. The `EvaluationReporter` reads only the fields relevant
/// to its feature when computing aggregate metrics.
///
/// ## When to use
///
/// You construct `EvaluationResult` inside your `EvaluationRunner.run(_:)` implementation.
/// Populate only the fields that your feature actually measures. Every feature must set
/// `id`, `isCorrect`, and `latencyMs`. Classification features also set `predictedLabel`
/// and `expectedLabel`. Retrieval features set `score` and optionally `secondaryScore`.
///
/// ## When not to use
///
/// `EvaluationResult` is not used in the judge evaluation path. `LLMJudgeRunner`
/// returns `JudgeResult` instead. Similarly, `RulesReporter` produces `RulesResult`
/// rather than `EvaluationResult`.
///
/// ## Usage example
///
/// ```swift
/// // Inside a classification runner:
/// func run(_ testCase: TextEvaluationCase) async throws -> EvaluationResult {
///     var latencyMs: Double = 0
///     let predicted = try await LatencyMeasurer.measure(into: &latencyMs) {
///         try await model.predict(testCase.input)
///     }
///     return EvaluationResult(
///         id: testCase.id,
///         isCorrect: predicted == testCase.expectedOutput,
///         latencyMs: latencyMs,
///         predictedLabel: predicted,
///         expectedLabel: testCase.expectedOutput
///     )
/// }
/// ```
public struct EvaluationResult: Sendable {

    // MARK: - Required

    /// Stable identifier matching `EvaluationCase.id`.
    ///
    /// Used to correlate results back to their source case when reviewing failures.
    /// Must match the `id` of the `EvaluationCase` that generated this result.
    public let id: String

    /// Whether this case is considered a pass.
    ///
    /// The semantic meaning depends on the feature type:
    /// - Classification: `predicted == expected`
    /// - Similarity (Jaccard/position): `score >= 1.0` (exact match only)
    /// - Similarity (BLEU/ROUGE): `score >= passingThreshold` (configurable)
    /// - Rules: all rules passed
    ///
    /// This field drives `EvaluationMetrics.passRate` and `EvaluationReport.passCount`.
    public let isCorrect: Bool

    /// End-to-end wall-clock latency for this case in milliseconds.
    ///
    /// Measures the time from sending the input to receiving the model's output.
    /// Lower is better. Aggregate using `EvaluationMetrics.latencyMsMean` for typical
    /// performance and `latencyMsP90` for worst-case UX impact.
    /// Use `LatencyMeasurer` to populate this field accurately.
    public let latencyMs: Double

    // MARK: - Classification

    /// The label produced by the model. `nil` for non-classification features.
    ///
    /// For CoreML classifiers, this is the model's top prediction string.
    /// For LLM-based classifiers, this is the parsed label from the LLM response.
    /// `nil` if the model threw before returning, or for retrieval/rules/judge features.
    public let predictedLabel: String?

    /// The ground-truth label from the test dataset. `nil` for non-classification features.
    ///
    /// Set from `EvaluationCase.expectedOutput` for classification tasks.
    /// `nil` for retrieval, rules, and judge evaluation paths.
    public let expectedLabel: String?

    // MARK: - Similarity / Retrieval

    /// Primary similarity score. `nil` for non-retrieval features.
    ///
    /// Populated by `SimilarityRunner` using the configured `SimilarityMetric`.
    /// - `1.0` = perfect match (identical sets for Jaccard, identical order for position,
    ///   identical text for BLEU/ROUGE).
    /// - `0.0` = no overlap at all.
    /// `nil` for classification, rules, and judge evaluation paths.
    public let score: Double?

    /// Secondary similarity score. `nil` when not applicable.
    ///
    /// Populated when `SimilarityRunner` is configured with a `secondaryMetric`
    /// (e.g. position similarity alongside a primary Jaccard score). `nil` when only
    /// one metric is needed, or for non-retrieval features.
    public let secondaryScore: Double?

    // MARK: - LLM quality

    /// `true` when the model returned an output outside the valid label vocabulary.
    ///
    /// Only meaningful for LLM-based classification paths where the model is prompted
    /// to return a label string. Always `false` for CoreML classifiers, which are
    /// constrained to their output vocabulary at the model level.
    public let hallucinationFlag: Bool

    // MARK: - Pipeline / fallback

    /// `true` when the keyword safety-net fired instead of the model result.
    ///
    /// Only meaningful for pipeline features with a fallback path (e.g. TopicFinder).
    /// A high rate of fallback usage indicates the primary model is underperforming.
    /// Always `false` for single-model features.
    public let usedFallback: Bool

    /// Confidence label of the top result. `nil` for most features.
    ///
    /// Populated for features that return a ranked result with a discrete confidence
    /// bucket (e.g. `"certain"`, `"most_likely"`, `"possible"`). Used to compute
    /// `EvaluationMetrics.confidenceAccuracy`. `nil` for CoreML classifiers and
    /// any feature without ranked confidence output.
    public let confidence: String?

    // MARK: - Packing list

    /// Number of items outside the canonical allow-list. `nil` for non-packing-list features.
    ///
    /// Set when the model output is a list of items and each is checked against a
    /// known vocabulary. A value of `0` means all items were valid. Higher values
    /// indicate hallucinated or out-of-vocabulary items. `nil` for all other feature types.
    public let itemErrorCount: Int?

    // MARK: - Error

    /// Non-nil when this case failed with an error and the result is unreliable.
    ///
    /// When `error` is set, `isCorrect` is always `false` and other metric fields
    /// (scores, labels) may be `nil` or at their zero/default value. A non-zero
    /// `errorCount` in the aggregate metrics signals that data is missing and may
    /// skew results.
    public let error: String?

    /// Optional free-text reasoning from the model. `nil` for CoreML and non-LLM features.
    ///
    /// Populated when an LLM returns a structured response that includes a reasoning
    /// field alongside its answer. Used only for debugging and display — not included
    /// in aggregate metrics. `nil` for all CoreML and non-LLM evaluation paths.
    public let reasoning: String?

    // MARK: - Init

    public init(
        id: String,
        isCorrect: Bool,
        latencyMs: Double,
        predictedLabel: String? = nil,
        expectedLabel: String? = nil,
        score: Double? = nil,
        secondaryScore: Double? = nil,
        hallucinationFlag: Bool = false,
        usedFallback: Bool = false,
        confidence: String? = nil,
        itemErrorCount: Int? = nil,
        error: String? = nil,
        reasoning: String? = nil
    ) {
        self.id = id
        self.isCorrect = isCorrect
        self.latencyMs = latencyMs
        self.predictedLabel = predictedLabel
        self.expectedLabel = expectedLabel
        self.score = score
        self.secondaryScore = secondaryScore
        self.hallucinationFlag = hallucinationFlag
        self.usedFallback = usedFallback
        self.confidence = confidence
        self.itemErrorCount = itemErrorCount
        self.error = error
        self.reasoning = reasoning
    }
}
