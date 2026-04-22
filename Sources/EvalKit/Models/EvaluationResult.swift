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
/// All fields that are not applicable to a given feature should be left `nil` /
/// default. The `EvaluationReporter` only uses the fields relevant to its
/// feature when computing aggregate metrics.
public struct EvaluationResult: Sendable {

    // MARK: - Required

    /// Stable identifier matching `EvaluationCase.id`.
    public let id: String

    /// Whether this case is considered a pass.
    ///
    /// - Classification: `predicted == expected`
    /// - Similarity: `score >= 1.0` (exact Jaccard match)
    /// - Validation: LLM format check returned "correct format"
    public let isCorrect: Bool

    /// End-to-end latency for this case in milliseconds.
    public let latencyMs: Double

    // MARK: - Classification (FeedbackClassification)

    /// The label produced by the model. `nil` for non-classification features.
    public let predictedLabel: String?

    /// The ground-truth label. `nil` for non-classification features.
    public let expectedLabel: String?

    // MARK: - Similarity (TopicFinder)

    /// Primary similarity score (Jaccard correctness). `nil` for non-similarity features.
    public let score: Double?

    /// Secondary similarity score (position relevance). `nil` when not applicable.
    public let secondaryScore: Double?

    // MARK: - LLM quality

    /// `true` when the model returned an output outside the valid label vocabulary.
    /// Only meaningful for LLM-based classification paths.
    public let hallucinationFlag: Bool

    // MARK: - Pipeline / fallback (TopicFinder)

    /// `true` when the keyword safety-net fired instead of the model result.
    /// Only meaningful for pipeline-based features (e.g. TopicFinder).
    public let usedFallback: Bool

    /// Confidence label of the top result, e.g. "certain", "most_likely".
    /// Only populated for features that return a ranked result with confidence.
    public let confidence: String?

    // MARK: - Packing list (PackingList)

    /// Number of items outside the canonical allow-list (diagnostic metric).
    /// Only populated for packing-list features.
    public let itemErrorCount: Int?

    // MARK: - Error

    /// Non-nil when this case failed with an error and the result is unreliable.
    public let error: String?

    /// Optional free-text reasoning from the model (LLM path only).
    /// Populated when the model returns a structured response with a reasoning field.
    /// Only used for display and debugging — not included in aggregate metrics.
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
