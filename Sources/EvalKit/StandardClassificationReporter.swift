// EvalKit — all processing is on-device. No data leaves the device.
//
// StandardClassificationReporter.swift
// EvalKit
//
// Ready-to-use EvaluationReporter for multi-class text classification.
// Computes accuracy, macro/weighted P/R/F1, latency mean and P90,
// and compares accuracy against a configurable minimum threshold.

import Foundation

/// A ready-to-use `EvaluationReporter` for multi-class text classification tasks.
///
/// Use this instead of writing your own reporter when your feature:
/// - Classifies text into one of N fixed labels
/// - Wants to gate on a minimum accuracy threshold
/// - Needs macro and weighted precision/recall/F1 in the report
///
/// ## Usage
///
/// ```swift
/// let labels = HelpCategory.allCases.map(\.rawValue)
/// let reporter = StandardClassificationReporter(labels: labels, minimumAccuracy: 0.85)
/// let report = reporter.report(from: results, featureName: "FeedbackClassification")
///
/// print(report.passedBaseline)            // true / false
/// print(report.metrics.accuracy ?? 0)     // e.g. 0.847
/// print(report.metrics.macroF1 ?? 0)      // e.g. 0.844
/// print(report.metrics.latencyMsMean)     // e.g. 859.4 ms
/// ```
///
/// If you need to track hallucinations or custom metrics, write a feature-specific
/// `EvaluationReporter` instead and use `PrecisionRecallF1.compute()` directly.
public struct StandardClassificationReporter: EvaluationReporter {

    /// The complete ordered label vocabulary. Must cover all possible labels in your dataset.
    public let labels: [String]

    /// Minimum accuracy required for the report to pass the baseline gate.
    /// Defaults to `0.85` (85%).
    public let minimumAccuracy: Double

    /// Create a reporter for a classification feature.
    ///
    /// - Parameters:
    ///   - labels: All possible label strings (e.g. `MyCategory.allCases.map(\.rawValue)`).
    ///   - minimumAccuracy: Accuracy threshold below which `report.passedBaseline` is `false`.
    ///                      Defaults to `0.85`.
    public init(labels: [String], minimumAccuracy: Double = 0.85) {
        self.labels = labels
        self.minimumAccuracy = minimumAccuracy
    }

    // MARK: - EvaluationReporter

    public func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
        let prf      = PrecisionRecallF1.compute(from: results, labels: labels)
        let latencies = results.map(\.latencyMs)

        let metrics = EvaluationMetrics(
            totalCases:        results.count,
            passRate:          prf.accuracy,
            errorCount:        results.filter { $0.error != nil }.count,
            accuracy:          prf.accuracy,
            macroPrecision:    prf.macroPrecision,
            macroRecall:       prf.macroRecall,
            macroF1:           prf.macroF1,
            weightedPrecision: prf.weightedPrecision,
            weightedRecall:    prf.weightedRecall,
            weightedF1:        prf.weightedF1,
            latencyMsMean:     P90Calculator.mean(latencies),
            latencyMsP90:      P90Calculator.p90(latencies)
        )

        return EvaluationReport(
            featureName:         featureName,
            metrics:             metrics,
            results:             results,
            passedBaseline:      prf.accuracy >= minimumAccuracy,
            baselineDescription: "accuracy >= \(minimumAccuracy)"
        )
    }
}
