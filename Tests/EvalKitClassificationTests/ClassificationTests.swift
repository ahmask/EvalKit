// EvalKit — all processing is on-device. No data leaves the device.
//
// ClassificationTests.swift
// EvalKitClassificationTests

import XCTest
import EvalKit
@testable import EvalKitClassification

final class ClassificationTests: XCTestCase {

    // MARK: - PrecisionRecallF1

    func test_prf1_perfect() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 12, predictedLabel: "dog", expectedLabel: "dog"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        XCTAssertEqual(output.accuracy, 1.0)
        XCTAssertEqual(output.macroF1, 1.0)
        XCTAssertEqual(output.weightedF1, 1.0)
    }

    func test_prf1_allWrong() {
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "dog", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: false, latencyMs: 12, predictedLabel: "cat", expectedLabel: "dog"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog"])
        XCTAssertEqual(output.accuracy, 0.0)
        XCTAssertEqual(output.macroF1, 0.0)
    }

    func test_prf1_classMetrics() {
        // 2 cats, 1 dog — model predicts correctly for both cats, misses dog
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "cat", expectedLabel: "cat"),
            EvaluationResult(id: "3", isCorrect: false, latencyMs: 10, predictedLabel: "cat", expectedLabel: "dog"),
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

    func test_prf1_confusionMatrix() {
        let results = [
            EvaluationResult(id: "1", isCorrect: true,  latencyMs: 10, predictedLabel: "A", expectedLabel: "A"),
            EvaluationResult(id: "2", isCorrect: false, latencyMs: 10, predictedLabel: "B", expectedLabel: "A"),
            EvaluationResult(id: "3", isCorrect: true,  latencyMs: 10, predictedLabel: "B", expectedLabel: "B"),
        ]
        let output = PrecisionRecallF1.compute(from: results, labels: ["A", "B"])
        // matrix[A][A]=1, matrix[A][B]=1, matrix[B][B]=1
        XCTAssertEqual(output.confusionMatrix.count(expected: "A", predicted: "A"), 1)
        XCTAssertEqual(output.confusionMatrix.count(expected: "A", predicted: "B"), 1)
        XCTAssertEqual(output.confusionMatrix.count(expected: "B", predicted: "B"), 1)
        XCTAssertEqual(output.confusionMatrix.count(expected: "B", predicted: "A"), 0)
    }

    // MARK: - FalseRateCalculator (binary)

    func test_frc_binary_allCorrect() {
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

    func test_frc_binary_falsePositive() {
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "spam",     expectedLabel: "not_spam"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "not_spam"),
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.falsePositiveCount, 1)
        XCTAssertEqual(output.falseNegativeCount, 0)
        // FPR = 1 / (1 + 1) = 0.5
        XCTAssertEqual(output.falsePositiveRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.falseNegativeRate, 0.0)
    }

    func test_frc_binary_falseNegative() {
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10, predictedLabel: "not_spam", expectedLabel: "spam"),
            EvaluationResult(id: "2", isCorrect: true,  latencyMs: 10, predictedLabel: "spam",     expectedLabel: "spam"),
        ]
        let output = FalseRateCalculator.compute(results: results, positiveLabel: "spam", negativeLabel: "not_spam")
        XCTAssertEqual(output.falseNegativeCount, 1)
        XCTAssertEqual(output.falsePositiveCount, 0)
        // FNR = 1 / (1 + 1) = 0.5
        XCTAssertEqual(output.falseNegativeRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.falsePositiveRate, 0.0)
    }

    func test_frc_multiclass_perfect() {
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

    // MARK: - StandardClassificationReporter

    func test_standardReporter_passedBaseline_atThreshold() {
        // 85% accuracy = exactly at threshold
        var results: [EvaluationResult] = []
        for i in 0..<85 {
            results.append(EvaluationResult(id: "\(i)", isCorrect: true, latencyMs: 10, predictedLabel: "A", expectedLabel: "A"))
        }
        for i in 85..<100 {
            results.append(EvaluationResult(id: "\(i)", isCorrect: false, latencyMs: 10, predictedLabel: "B", expectedLabel: "A"))
        }
        let reporter = StandardClassificationReporter(labels: ["A", "B"], minimumAccuracy: 0.85)
        let report = reporter.report(from: results, featureName: "Test")
        XCTAssertTrue(report.passedBaseline)
        XCTAssertEqual(report.metrics.accuracy ?? 0, 0.85, accuracy: 0.001)
    }

    func test_standardReporter_failedBaseline_belowThreshold() {
        var results: [EvaluationResult] = []
        for i in 0..<80 {
            results.append(EvaluationResult(id: "\(i)", isCorrect: true, latencyMs: 10, predictedLabel: "A", expectedLabel: "A"))
        }
        for i in 80..<100 {
            results.append(EvaluationResult(id: "\(i)", isCorrect: false, latencyMs: 10, predictedLabel: "B", expectedLabel: "A"))
        }
        let reporter = StandardClassificationReporter(labels: ["A", "B"], minimumAccuracy: 0.85)
        let report = reporter.report(from: results, featureName: "Test")
        XCTAssertFalse(report.passedBaseline)
        XCTAssertEqual(report.metrics.accuracy ?? 0, 0.80, accuracy: 0.001)
    }

    // MARK: - MultiLabelClassificationReporter

    func test_multiLabelReporter_perfectF1() {
        // All cases: predicted == expected
        let results = [
            EvaluationResult(id: "1", isCorrect: true, latencyMs: 10,
                             predictedLabel: "beach,sunset", expectedLabel: "beach,sunset"),
            EvaluationResult(id: "2", isCorrect: true, latencyMs: 10,
                             predictedLabel: "food", expectedLabel: "food"),
        ]
        let reporter = MultiLabelClassificationReporter(labels: ["beach", "sunset", "food"])
        let report = reporter.report(from: results, featureName: "Tagging")
        XCTAssertEqual(report.metrics.macroF1 ?? 0, 1.0, accuracy: 0.001)
        XCTAssertTrue(report.passedBaseline)
    }

    func test_multiLabelReporter_partialF1() {
        // Case 1: predicted "beach,sunset", expected "beach,travel" → beach TP, sunset FP, travel FN
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10,
                             predictedLabel: "beach,sunset", expectedLabel: "beach,travel"),
        ]
        let labels = ["beach", "sunset", "travel"]
        let reporter = MultiLabelClassificationReporter(labels: labels, minimumF1: 0.50)
        let report = reporter.report(from: results, featureName: "Tagging")
        // beach: TP=1, FP=0, FN=0 → F1=1.0
        // sunset: TP=0, FP=1, FN=0 → F1=0.0
        // travel: TP=0, FP=0, FN=1 → F1=0.0
        // macroF1 = (1.0 + 0.0 + 0.0) / 3 ≈ 0.333
        XCTAssertEqual(report.metrics.macroF1 ?? 0, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertFalse(report.passedBaseline)
    }

    func test_multiLabelReporter_microF1() {
        // Verify microF1 (stored in weightedF1) is computed correctly
        // Case: predicted "A,B", expected "A,C"
        // A: TP=1, B: FP=1, C: FN=1
        // micro: TP=1, FP=1, FN=1 → precision=0.5, recall=0.5, F1=0.5
        let results = [
            EvaluationResult(id: "1", isCorrect: false, latencyMs: 10,
                             predictedLabel: "A,B", expectedLabel: "A,C"),
        ]
        let reporter = MultiLabelClassificationReporter(labels: ["A", "B", "C"])
        let report = reporter.report(from: results, featureName: "Tagging")
        XCTAssertEqual(report.metrics.weightedF1 ?? 0, 0.5, accuracy: 0.01)
    }
}
