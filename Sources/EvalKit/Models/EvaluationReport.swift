// EvalKit — all processing is on-device. No data leaves the device.
//
// EvaluationReport.swift
// EvalKit/Models
//
// Final aggregated report produced by an EvaluationReporter.

import Foundation

/// The final output of a complete evaluation run.
///
/// Contains the computed metrics, all raw results, a pass/fail verdict against
/// a baseline, and the timestamp of the run. This struct is what drives the
/// evaluation UI and CI pass/fail gate.
public struct EvaluationReport: Sendable {

    /// Human-readable feature name (e.g. "FeedbackClassification-CoreML").
    public let featureName: String

    /// Aggregated metrics for this run.
    public let metrics: EvaluationMetrics

    /// All per-case raw results.
    public let results: [EvaluationResult]

    /// `true` when `metrics` meet or exceed the feature's defined baseline.
    public let passedBaseline: Bool

    /// Human-readable description of the baseline requirement, e.g.
    /// "accuracy >= 0.85" or "jaccard_mean >= 0.75".
    public let baselineDescription: String?

    /// When this report was generated.
    public let generatedAt: Date

    /// Number of cases where `isCorrect == true`.
    public var passCount: Int {
        results.filter(\.isCorrect).count
    }

    // MARK: - Init

    public init(
        featureName: String,
        metrics: EvaluationMetrics,
        results: [EvaluationResult],
        passedBaseline: Bool,
        baselineDescription: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.featureName = featureName
        self.metrics = metrics
        self.results = results
        self.passedBaseline = passedBaseline
        self.baselineDescription = baselineDescription
        self.generatedAt = generatedAt
    }
}
