// EvalKit — all processing is on-device. No data leaves the device.
//
// MetricsTests.swift
// EvalKitTests

import XCTest
@testable import EvalKit

final class MetricsTests: XCTestCase {

    // MARK: - PrecisionRecallF1

    func test_precisionRecallF1_perfect() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true, latencyMs: 12, predictedLabel: "dog", expectedLabel: "dog")
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        XCTAssertEqual(output.accuracy, 1.0)
        XCTAssertEqual(output.macroF1, 1.0)
        XCTAssertEqual(output.weightedF1, 1.0)
    }

    func test_precisionRecallF1_allWrong() {
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "dog", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: false, latencyMs: 12, predictedLabel: "cat", expectedLabel: "dog")
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        XCTAssertEqual(output.accuracy, 0.0)
        XCTAssertEqual(output.macroF1, 0.0)
    }

    func test_precisionRecallF1_classMetrics() {
        // 2 cats, 1 dog — model predicts correctly for both cats, misses dog
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "3", isCorrect: false, latencyMs: 10, predictedLabel: "cat", expectedLabel: "dog")
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        let catMetrics = output.classMetrics.first { $0.label == "cat" }!
        let dogMetrics = output.classMetrics.first { $0.label == "dog" }!

        // cat: TP=2, FP=1, FN=0 → P=2/3, R=1.0
        XCTAssertEqual(catMetrics.truePositives, 2)
        XCTAssertEqual(catMetrics.falsePositives, 1)
        XCTAssertEqual(catMetrics.falseNegatives, 0)
        XCTAssertEqual(catMetrics.precision, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(catMetrics.recall, 1.0)

        // dog: TP=0, FP=0, FN=1 → P=0, R=0
        XCTAssertEqual(dogMetrics.truePositives, 0)
        XCTAssertEqual(dogMetrics.falseNegatives, 1)
        XCTAssertEqual(dogMetrics.precision, 0.0)
        XCTAssertEqual(dogMetrics.recall, 0.0)

        XCTAssertEqual(output.accuracy, 2.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - P90Calculator

    func test_p90_sorted() {
        let values = Array(1...10).map(Double.init)
        let p90 = P90Calculator.p90(values)
        // numpy.percentile([1..10], 90) = 9.1
        XCTAssertEqual(p90, 9.1, accuracy: 0.01)
    }

    func test_p90_empty() {
        XCTAssertEqual(P90Calculator.p90([]), 0.0)
    }

    func test_mean() {
        XCTAssertEqual(P90Calculator.mean([1, 2, 3, 4, 5]), 3.0)
        XCTAssertEqual(P90Calculator.mean([]), 0.0)
    }

    func test_standardDeviation() {
        // numpy.std([2,4,4,4,5,5,7,9]) = 2.0
        let values: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
        XCTAssertEqual(P90Calculator.standardDeviation(values), 2.0, accuracy: 0.001)
    }

    // MARK: - LatencyMeasurer

    func test_latencyMeasurer_returnsResult() async throws {
        let (result, latencyMs) = await LatencyMeasurer.measure {
            "hello"
        }
        XCTAssertEqual(result, "hello")
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_into() async throws {
        var latencyMs: Double = 0
        let result = await LatencyMeasurer.measure(into: &latencyMs) {
            42
        }
        XCTAssertEqual(result, 42)
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_measureCapturingErrors_onSuccess_recordsLatency() async throws {
        var latencyMs: Double = 0
        let result = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) {
            "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_measureCapturingErrors_onError_stillRecordsLatency() async throws {
        struct TestError: Error {}
        var latencyMs: Double = 0
        do {
            _ = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) {
                throw TestError()
            }
            XCTFail("Expected error to be thrown")
        } catch {
            // Latency must have been recorded even though the operation failed
            XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
        }
    }

    // MARK: - FalseRateCalculator (binary)

    func test_falseRateCalculator_binary_allCorrect() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "spam",     expectedLabel: "spam"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "not_spam"),
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.falsePositiveCount, 0)
        XCTAssertEqual(output.falseNegativeCount, 0)
        XCTAssertEqual(output.truePositiveCount,  1)
        XCTAssertEqual(output.trueNegativeCount,  1)
        XCTAssertEqual(output.falsePositiveRate, 0.0)
        XCTAssertEqual(output.falseNegativeRate, 0.0)
    }

    func test_falseRateCalculator_binary_falsePositive() {
        // Model predicts spam, but actual is not_spam → FP
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "spam", expectedLabel: "not_spam"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "not_spam"),
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.falsePositiveCount, 1)
        XCTAssertEqual(output.falseNegativeCount, 0)
        XCTAssertEqual(output.trueNegativeCount,  1)
        // FPR = 1 / (1 + 1) = 0.5
        XCTAssertEqual(output.falsePositiveRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.falseNegativeRate, 0.0)
    }

    func test_falseRateCalculator_binary_falseNegative() {
        // Model predicts not_spam, but actual is spam → FN
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "spam"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "spam",     expectedLabel: "spam"),
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.falseNegativeCount, 1)
        XCTAssertEqual(output.falsePositiveCount, 0)
        XCTAssertEqual(output.truePositiveCount,  1)
        // FNR = 1 / (1 + 1) = 0.5
        XCTAssertEqual(output.falseNegativeRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.falsePositiveRate, 0.0)
    }

    func test_falseRateCalculator_binary_mixed() {
        // 2 TP, 1 FP, 1 FN, 1 TN
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "spam",     expectedLabel: "spam"),     // TP
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "spam",     expectedLabel: "spam"),     // TP
            EvaluationResult(id: "3", isCorrect: false, latencyMs: 10, predictedLabel: "spam",     expectedLabel: "not_spam"), // FP
            EvaluationResult(id: "4", isCorrect: false, latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "spam"),     // FN
            EvaluationResult(id: "5", isCorrect: true,  latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "not_spam"), // TN
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.truePositiveCount,  2)
        XCTAssertEqual(output.falsePositiveCount, 1)
        XCTAssertEqual(output.falseNegativeCount, 1)
        XCTAssertEqual(output.trueNegativeCount,  1)
        // FPR = FP / (FP + TN) = 1 / (1 + 1) = 0.5
        XCTAssertEqual(output.falsePositiveRate, 0.5, accuracy: 0.001)
        // FNR = FN / (FN + TP) = 1 / (1 + 2) = 0.333...
        XCTAssertEqual(output.falseNegativeRate, 1.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - FalseRateCalculator (multi-class)

    func test_falseRateCalculator_multiclass_perfect() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 10, predictedLabel: "A", expectedLabel: "A"),
            EvaluationResult(id: "2", isCorrect: true, latencyMs: 10, predictedLabel: "B", expectedLabel: "B"),
            EvaluationResult(id: "3", isCorrect: true, latencyMs: 10, predictedLabel: "C", expectedLabel: "C"),
        ]
        let output = FalseRateCalculator.compute(results: results, labels: ["A", "B", "C"])
        XCTAssertEqual(output.falsePositiveCount, 0)
        XCTAssertEqual(output.falseNegativeCount, 0)
        XCTAssertEqual(output.falsePositiveRate, 0.0)
        XCTAssertEqual(output.falseNegativeRate, 0.0)
    }

    func test_falseRateCalculator_multiclass_errors() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "A", expectedLabel: "A"),
            EvaluationResult(id: "2", isCorrect: false, latencyMs: 10, predictedLabel: "A", expectedLabel: "B"), // FP for A, FN for B
        ]
        let output = FalseRateCalculator.compute(results: results, labels: ["A", "B"])
        XCTAssertEqual(output.falsePositiveCount, 1) // A predicted but actually B
        XCTAssertEqual(output.falseNegativeCount, 1) // B expected but predicted A
    }

    // MARK: - EvaluationResult new fields

    func test_evaluationResult_usedFallback_default() {
        let r = EvaluationResult(id: "1", isCorrect: true, latencyMs: 10)
        XCTAssertFalse(r.usedFallback)
        XCTAssertNil(r.confidence)
        XCTAssertNil(r.itemErrorCount)
    }

    func test_evaluationResult_usedFallback_set() {
        let r = EvaluationResult(
            id: "1", isCorrect: true, latencyMs: 10,
            usedFallback: true, confidence: "certain", itemErrorCount: 3
        )
        XCTAssertTrue(r.usedFallback)
        XCTAssertEqual(r.confidence, "certain")
        XCTAssertEqual(r.itemErrorCount, 3)
    }

    // MARK: - EvaluationReport passCount

    func test_evaluationReport_passCount() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10),
            EvaluationResult(id: "2", isCorrect: false, latencyMs: 10),
            EvaluationResult(id: "3", isCorrect: true,  latencyMs: 10),
        ]
        let metrics = EvaluationMetrics(
            totalCases: 3, passRate: 2.0/3.0, errorCount: 0,
            latencyMsMean: 10, latencyMsP90: 10
        )
        let report = EvaluationReport(
            featureName: "Test",
            metrics: metrics,
            results: results,
            passedBaseline: true
        )
        XCTAssertEqual(report.passCount, 2)
    }

    // MARK: - PrecisionRecallF1 confusion matrix

    func test_confusionMatrix_perfectPredictions() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true, latencyMs: 10, predictedLabel: "dog", expectedLabel: "dog"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        let cm = output.confusionMatrix

        XCTAssertEqual(cm.labels, ["cat", "dog"])
        XCTAssertEqual(cm.count(expected: "cat", predicted: "cat"), 1)
        XCTAssertEqual(cm.count(expected: "dog", predicted: "dog"), 1)
        XCTAssertEqual(cm.count(expected: "cat", predicted: "dog"), 0)
        XCTAssertEqual(cm.count(expected: "dog", predicted: "cat"), 0)
    }

    func test_confusionMatrix_withErrors() {
        // cat predicted as dog, dog predicted correctly
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "dog", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "dog", expectedLabel: "dog"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        let cm = output.confusionMatrix

        XCTAssertEqual(cm.count(expected: "cat", predicted: "dog"), 1) // misclassification
        XCTAssertEqual(cm.count(expected: "dog", predicted: "dog"), 1) // correct
        XCTAssertEqual(cm.count(expected: "cat", predicted: "cat"), 0)
    }

    func test_confusionMatrix_unknownLabelReturnsZero() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        let cm = output.confusionMatrix

        XCTAssertEqual(cm.count(expected: "unknown", predicted: "cat"), 0)
    }

    // MARK: - StandardClassificationReporter

    func test_standardClassificationReporter_passesWhenAboveThreshold() {
        // 9/10 correct → 90% accuracy, threshold 0.85 → should pass
        let results = (1...9).map {
            EvaluationResult(id: "\($0)", isCorrect: true,  latencyMs: 10, predictedLabel: "A", expectedLabel: "A")
        } + [EvaluationResult(id: "10", isCorrect: false, latencyMs: 10, predictedLabel: "B", expectedLabel: "A")]

        let reporter = StandardClassificationReporter(labels: ["A", "B"], minimumAccuracy: 0.85)
        let report = reporter.report(from: results, featureName: "TestFeature")

        XCTAssertTrue(report.passedBaseline)
        XCTAssertEqual(report.metrics.accuracy ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(report.featureName, "TestFeature")
    }

    func test_standardClassificationReporter_failsWhenBelowThreshold() {
        // 5/10 correct → 50% accuracy, threshold 0.85 → should fail
        let results = (1...5).map {
            EvaluationResult(id: "\($0)", isCorrect: true,  latencyMs: 10, predictedLabel: "A", expectedLabel: "A")
        } + (6...10).map {
            EvaluationResult(id: "\($0)", isCorrect: false, latencyMs: 10, predictedLabel: "B", expectedLabel: "A")
        }

        let reporter = StandardClassificationReporter(labels: ["A", "B"], minimumAccuracy: 0.85)
        let report = reporter.report(from: results, featureName: "TestFeature")

        XCTAssertFalse(report.passedBaseline)
    }

    func test_standardClassificationReporter_customThreshold() {
        // 6/10 correct → 60% accuracy, threshold 0.5 → should pass
        let results = (1...6).map {
            EvaluationResult(id: "\($0)", isCorrect: true,  latencyMs: 5, predictedLabel: "A", expectedLabel: "A")
        } + (7...10).map {
            EvaluationResult(id: "\($0)", isCorrect: false, latencyMs: 5, predictedLabel: "B", expectedLabel: "A")
        }

        let reporter = StandardClassificationReporter(labels: ["A", "B"], minimumAccuracy: 0.5)
        let report = reporter.report(from: results, featureName: "Custom")

        XCTAssertTrue(report.passedBaseline)
        XCTAssertEqual(report.baselineDescription, "accuracy >= 0.5")
    }

    func test_standardClassificationReporter_includesLatencyMetrics() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 100, predictedLabel: "A", expectedLabel: "A"),
            EvaluationResult(id: "2", isCorrect: true, latencyMs: 200, predictedLabel: "A", expectedLabel: "A"),
        ]
        let reporter = StandardClassificationReporter(labels: ["A"])
        let report = reporter.report(from: results, featureName: "Latency")

        XCTAssertEqual(report.metrics.latencyMsMean, 150.0, accuracy: 0.001)
        XCTAssertGreaterThan(report.metrics.latencyMsP90, 0)
    }
}
