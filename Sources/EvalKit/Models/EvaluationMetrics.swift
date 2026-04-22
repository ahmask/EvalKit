// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationMetrics.swift
// EvalKit/Models
//
// Aggregated metrics computed from a batch of EvaluationResults.
// Covers all metric types computed by the existing on-device projects.

import Foundation

/// Aggregated evaluation metrics for a feature's evaluation run.
///
/// Fields that do not apply to a given feature are `nil`. Only populate the
/// fields your feature uses — the reporter constructs this struct directly.
public struct EvaluationMetrics: Sendable {

    // MARK: - Universal

    /// Total number of test cases evaluated.
    public let totalCases: Int

    /// Fraction of cases that passed (`isCorrect == true`).
    /// Equals `accuracy` for classification tasks.
    public let passRate: Double

    /// Number of cases that produced an error.
    public let errorCount: Int

    // MARK: - Classification (FeedbackClassification)

    /// Overall classification accuracy. `nil` for non-classification features.
    public let accuracy: Double?

    /// Macro-averaged precision across all classes. `nil` for non-classification features.
    public let macroPrecision: Double?

    /// Macro-averaged recall across all classes. `nil` for non-classification features.
    public let macroRecall: Double?

    /// Macro-averaged F1 score. `nil` for non-classification features.
    public let macroF1: Double?

    /// Support-weighted precision. `nil` for non-classification features.
    public let weightedPrecision: Double?

    /// Support-weighted recall. `nil` for non-classification features.
    public let weightedRecall: Double?

    /// Support-weighted F1 score. `nil` for non-classification features.
    public let weightedF1: Double?

    // MARK: - Latency

    /// Mean end-to-end latency across all cases in milliseconds.
    public let latencyMsMean: Double

    /// 90th-percentile latency in milliseconds.
    public let latencyMsP90: Double

    // MARK: - Similarity (TopicFinder — Jaccard / position)

    /// Mean of the primary similarity score (Jaccard). `nil` for non-similarity features.
    public let scoreMean: Double?

    /// Standard deviation of the primary similarity score. `nil` when not applicable.
    public let scoreStd: Double?

    /// 90th-percentile of the primary similarity score. `nil` when not applicable.
    public let scoreP90: Double?

    /// Mean of the secondary similarity score (position). `nil` when not applicable.
    public let secondaryScoreMean: Double?

    /// Standard deviation of the secondary similarity score. `nil` when not applicable.
    public let secondaryScoreStd: Double?

    /// 90th-percentile of the secondary similarity score. `nil` when not applicable.
    public let secondaryScoreP90: Double?

    // MARK: - LLM quality

    /// Total hallucination events (model returned invalid output). `nil` for CoreML.
    public let hallucinationCount: Int?

    /// hallucinationCount / responded cases. `nil` for CoreML.
    public let hallucinationRate: Double?

    // MARK: - Pipeline quality (TopicFinder)

    /// Fraction of cases where the top result was `certain` or `most_likely`.
    /// Only applicable to features that return ranked results with confidence labels.
    public let confidenceAccuracy: Double?

    /// Fraction of cases where the keyword safety-net fired instead of the model. `nil` when N/A.
    public let fallbackRate: Double?

    // MARK: - Packing list quality (PackingList)

    /// Mean number of items outside the canonical allow-list per case. `nil` when N/A.
    public let avgItemErrorCount: Double?

    // MARK: - Binary classification / detection

    /// Number of false positives (predicted positive, actual negative). `nil` when N/A.
    public let falsePositiveCount: Int?

    /// Number of false negatives (predicted negative, actual positive). `nil` when N/A.
    public let falseNegativeCount: Int?

    /// FP / (FP + TN). `nil` when N/A or when TN count cannot be determined.
    public let falsePositiveRate: Double?

    /// FN / (FN + TP). `nil` when N/A or when TP count cannot be determined.
    public let falseNegativeRate: Double?

    // MARK: - Init

    public init(
        totalCases: Int,
        passRate: Double,
        errorCount: Int,
        accuracy: Double? = nil,
        macroPrecision: Double? = nil,
        macroRecall: Double? = nil,
        macroF1: Double? = nil,
        weightedPrecision: Double? = nil,
        weightedRecall: Double? = nil,
        weightedF1: Double? = nil,
        latencyMsMean: Double,
        latencyMsP90: Double,
        scoreMean: Double? = nil,
        scoreStd: Double? = nil,
        scoreP90: Double? = nil,
        secondaryScoreMean: Double? = nil,
        secondaryScoreStd: Double? = nil,
        secondaryScoreP90: Double? = nil,
        hallucinationCount: Int? = nil,
        hallucinationRate: Double? = nil,
        confidenceAccuracy: Double? = nil,
        fallbackRate: Double? = nil,
        avgItemErrorCount: Double? = nil,
        falsePositiveCount: Int? = nil,
        falseNegativeCount: Int? = nil,
        falsePositiveRate: Double? = nil,
        falseNegativeRate: Double? = nil
    ) {
        self.totalCases = totalCases
        self.passRate = passRate
        self.errorCount = errorCount
        self.accuracy = accuracy
        self.macroPrecision = macroPrecision
        self.macroRecall = macroRecall
        self.macroF1 = macroF1
        self.weightedPrecision = weightedPrecision
        self.weightedRecall = weightedRecall
        self.weightedF1 = weightedF1
        self.latencyMsMean = latencyMsMean
        self.latencyMsP90 = latencyMsP90
        self.scoreMean = scoreMean
        self.scoreStd = scoreStd
        self.scoreP90 = scoreP90
        self.secondaryScoreMean = secondaryScoreMean
        self.secondaryScoreStd = secondaryScoreStd
        self.secondaryScoreP90 = secondaryScoreP90
        self.hallucinationCount = hallucinationCount
        self.hallucinationRate = hallucinationRate
        self.confidenceAccuracy = confidenceAccuracy
        self.fallbackRate = fallbackRate
        self.avgItemErrorCount = avgItemErrorCount
        self.falsePositiveCount = falsePositiveCount
        self.falseNegativeCount = falseNegativeCount
        self.falsePositiveRate = falsePositiveRate
        self.falseNegativeRate = falseNegativeRate
    }
}
