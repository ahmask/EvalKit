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
/// ## Purpose
///
/// `EvaluationMetrics` is a flat container for every numeric metric EvalKit can
/// compute. Reporters construct it directly after processing a batch of results,
/// populating only the fields relevant to their feature type and leaving everything
/// else `nil`. The struct is then embedded in `EvaluationReport` for consumption
/// by CI gates and evaluation UIs.
///
/// ## When to use
///
/// You construct `EvaluationMetrics` inside your `EvaluationReporter.report(from:featureName:)`
/// implementation. Use the named parameters to fill in the fields your feature measures.
/// All other fields default to `nil` and will be ignored by reporting tools.
///
/// ## When not to use
///
/// For judge evaluation, use `JudgeMetrics` (EvalKitJudge) instead — it has
/// per-dimension breakdowns that this flat struct cannot represent.
/// For rules evaluation, pass rate information lives in `RulesReport` directly.
public struct EvaluationMetrics: Sendable {

    // MARK: - Universal

    /// Total number of test cases passed to the reporter.
    ///
    /// The baseline denominator for all rate metrics. A low count (< 50) may
    /// make percentile metrics unreliable — collect more test cases before
    /// drawing conclusions from P90 or standard deviation values.
    public let totalCases: Int

    /// Fraction of cases where `isCorrect == true`, in `[0.0, 1.0]`.
    ///
    /// - `1.0` = every case passed.
    /// - `0.0` = every case failed.
    ///
    /// For classification features, `passRate` equals `accuracy`. Use this as
    /// the primary health signal when a feature-specific metric is not available.
    public let passRate: Double

    /// Number of cases where the model or pipeline threw an error.
    ///
    /// A non-zero `errorCount` means data is missing — those cases did not
    /// contribute to accuracy, score, or F1 metrics. High error counts may
    /// silently inflate accuracy by excluding all hard cases. Always inspect
    /// `errorCount` before drawing conclusions from aggregate metrics.
    public let errorCount: Int

    // MARK: - Classification

    // MARK: - Classification

    /// Overall fraction of correctly classified examples. `nil` for non-classification features.
    ///
    /// - `1.0` = every prediction was correct.
    /// - `0.0` = every prediction was wrong.
    ///
    /// A value below `minimumAccuracy` will cause `StandardClassificationReporter`
    /// to set `passedBaseline = false`. For imbalanced datasets, combine with
    /// `macroF1` to avoid being misled by class-frequency skew.
    public let accuracy: Double?

    /// Unweighted mean of per-class precision across all labels. `nil` for non-classification.
    ///
    /// Precision for a class = TP / (TP + FP). Macro averages it equally across all classes.
    /// - `1.0` = no false positives for any class.
    /// - `0.0` = all predictions for every class were wrong.
    ///
    /// Use macro metrics when all classes matter equally regardless of how frequently
    /// they appear in your dataset. If common classes should dominate, use weighted instead.
    public let macroPrecision: Double?

    /// Unweighted mean of per-class recall across all labels. `nil` for non-classification.
    ///
    /// Recall for a class = TP / (TP + FN). Macro averages equally across classes.
    /// - `1.0` = no missed examples for any class.
    /// - `0.0` = every positive example was missed.
    ///
    /// Prioritise recall when missing a positive is more costly than a false alarm
    /// (e.g. safety classifiers, fraud detection).
    public let macroRecall: Double?

    /// Unweighted mean of per-class F1 score. `nil` for non-classification features.
    ///
    /// F1 is the harmonic mean of precision and recall. Macro averages equally across classes.
    /// - `1.0` = perfect precision and recall across all classes.
    /// - `0.0` = no class was correctly predicted at all.
    ///
    /// Use `macroF1` as your primary quality metric when classes are imbalanced — it gives
    /// equal weight to rare classes. Use `weightedF1` when frequent classes should count more.
    /// `nil` for non-classification features.
    public let macroF1: Double?

    /// Support-weighted mean of per-class precision. `nil` for non-classification features.
    ///
    /// Weighted by the number of ground-truth examples per class (`support`).
    /// Dominated by the most common classes in your dataset.
    /// Use when frequent classes should contribute more to the overall precision signal.
    public let weightedPrecision: Double?

    /// Support-weighted mean of per-class recall. `nil` for non-classification features.
    ///
    /// Weighted by the number of ground-truth examples per class (`support`).
    /// Use when frequent classes should contribute more to the overall recall signal.
    public let weightedRecall: Double?

    /// Support-weighted mean of per-class F1 score. `nil` for non-classification features.
    ///
    /// The most commonly reported F1 in imbalanced datasets because frequent classes
    /// dominate. Compare against `macroF1` — a large gap between them indicates your
    /// model performs well on common classes but fails on rare ones.
    /// `nil` for non-classification features.
    public let weightedF1: Double?

    // MARK: - Latency

    /// Mean end-to-end latency across all cases in milliseconds.
    ///
    /// Measures typical model speed. Compare across model versions to detect
    /// performance regressions. Does not capture outlier behaviour — use
    /// `latencyMsP90` for worst-case UX impact.
    public let latencyMsMean: Double

    /// 90th-percentile end-to-end latency in milliseconds.
    ///
    /// 90% of cases completed within this many milliseconds. More meaningful than
    /// the mean for UX assessment: if P90 is 3 000 ms, one in ten users experiences
    /// a 3-second wait. Target a P90 that fits within your UX loading budget.
    public let latencyMsP90: Double

    // MARK: - Similarity / Retrieval

    /// Mean of the primary similarity score (Jaccard, BLEU, ROUGE, or position).
    /// `nil` for non-retrieval features.
    ///
    /// - `1.0` = perfect retrieval quality on every case.
    /// - `0.0` = no overlap between predicted and expected on every case.
    ///
    /// A value below `minimumMeanScore` causes `RetrievalReporter` to set
    /// `passedBaseline = false`.
    public let scoreMean: Double?

    /// Population standard deviation of the primary similarity score. `nil` for non-retrieval.
    ///
    /// - Low std = consistent quality across cases.
    /// - High std = wildly varying results — some cases score well, others fail.
    ///
    /// Investigate high-std cases individually to find systematic failure patterns.
    public let scoreStd: Double?

    /// 90th-percentile of the primary similarity score. `nil` for non-retrieval.
    ///
    /// 90% of cases achieved at least this score. Measures how good the top 90%
    /// of results are, excluding the worst 10%. Useful for spotting a long tail
    /// of poor-quality retrievals.
    public let scoreP90: Double?

    /// Mean of the secondary similarity score (e.g. position match alongside Jaccard).
    /// `nil` when no secondary metric is configured or for non-retrieval features.
    public let secondaryScoreMean: Double?

    /// Population standard deviation of the secondary similarity score. `nil` when not applicable.
    public let secondaryScoreStd: Double?

    /// 90th-percentile of the secondary similarity score. `nil` when not applicable.
    public let secondaryScoreP90: Double?

    // MARK: - LLM quality

    /// Total number of cases where the model returned output outside the valid vocabulary.
    /// `nil` for CoreML classifiers.
    ///
    /// A non-zero count means the LLM invented labels that do not exist in the label set.
    /// Even a single hallucination is a reliability signal. `nil` for CoreML classifiers,
    /// which are physically constrained to their output vocabulary.
    public let hallucinationCount: Int?

    /// `hallucinationCount / responded cases`. `nil` for CoreML classifiers.
    ///
    /// - `0.0` = no hallucinations.
    /// - `1.0` = every response was invalid.
    ///
    /// Even a rate of `0.01` (1%) may be unacceptable for safety-critical or
    /// customer-facing classification features. Treat as a hard gate, not a soft metric.
    public let hallucinationRate: Double?

    // MARK: - Pipeline quality

    /// Fraction of cases where the top result was `"certain"` or `"most_likely"`.
    /// `nil` for features without ranked confidence output.
    ///
    /// - `1.0` = the model was maximally confident on every case.
    /// - Low values indicate the model is uncertain and the threshold logic should be reviewed.
    ///
    /// Only applicable to features that return ranked results with discrete confidence buckets.
    public let confidenceAccuracy: Double?

    /// Fraction of cases where the keyword safety-net fired instead of the model result.
    /// `nil` when the feature has no fallback path.
    ///
    /// - `0.0` = the primary model handled every case.
    /// - High values indicate the primary model is failing and the fallback is doing heavy lifting.
    ///
    /// A rising `fallbackRate` between evaluation runs is a signal of model quality regression.
    public let fallbackRate: Double?

    // MARK: - Packing list quality

    /// Mean number of items outside the canonical allow-list per case. `nil` for non-packing-list features.
    ///
    /// - `0.0` = every item in every output was in the allowed vocabulary.
    /// - Higher values = the model is hallucinating out-of-vocabulary items.
    ///
    /// Use `AllowedItemsRule` (EvalKitRules) to get per-case item error counts that feed this metric.
    public let avgItemErrorCount: Double?

    // MARK: - Binary classification / detection

    /// Total false positives across the batch (predicted positive, actual negative).
    /// `nil` when not computed via `FalseRateCalculator`.
    ///
    /// A false positive means the model flagged something incorrectly as positive.
    /// In spam filtering: a legitimate email was marked as spam. Populate via
    /// `FalseRateCalculator.compute(results:positiveLabel:negativeLabel:)`.
    public let falsePositiveCount: Int?

    /// Total false negatives across the batch (predicted negative, actual positive).
    /// `nil` when not computed via `FalseRateCalculator`.
    ///
    /// A false negative means the model missed a positive. In fraud detection:
    /// a fraudulent transaction was let through. This is often the most costly error type.
    public let falseNegativeCount: Int?

    /// FP / (FP + TN) — the false-positive rate. `nil` when not computed.
    ///
    /// - `0.0` = no spurious positive predictions (no false alarms).
    /// - `1.0` = every negative example was incorrectly predicted as positive.
    ///
    /// Also called "fall-out". Populate via `FalseRateCalculator`.
    public let falsePositiveRate: Double?

    /// FN / (FN + TP) — the false-negative rate. `nil` when not computed.
    ///
    /// - `0.0` = no positive examples were missed.
    /// - `1.0` = every positive example was missed.
    ///
    /// Also called "miss rate". Critical metric for safety, fraud, and medical triage
    /// features where missing a positive is more costly than a false alarm.
    /// Populate via `FalseRateCalculator`.
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
