// EvalKit — all processing is on-device. No data leaves the device.
//
// MetricsTests.swift
// EvalKitTests

import XCTest
@testable import EvalKit

final class MetricsTests: XCTestCase {

    // MARK: - P90Calculator

    func test_p90_sorted() {
        let values = Array(1...10).map(Double.init)
        let p90 = P90Calculator.p90(values)
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
        let values: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
        XCTAssertEqual(P90Calculator.standardDeviation(values), 2.0, accuracy: 0.001)
    }

    // MARK: - LatencyMeasurer

    func test_latencyMeasurer_returnsResult() async throws {
        let (result, latencyMs) = await LatencyMeasurer.measure { "hello" }
        XCTAssertEqual(result, "hello")
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_into() async throws {
        var latencyMs: Double = 0
        let result = await LatencyMeasurer.measure(into: &latencyMs) { 42 }
        XCTAssertEqual(result, 42)
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_measureCapturingErrors_onSuccess_recordsLatency() async throws {
        var latencyMs: Double = 0
        let result = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) { "success" }
        XCTAssertEqual(result, "success")
        XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
    }

    func test_latencyMeasurer_measureCapturingErrors_onError_stillRecordsLatency() async throws {
        struct TestError: Error {}
        var latencyMs: Double = 0
        do {
            _ = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) { throw TestError() }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertGreaterThanOrEqual(latencyMs, 0.0)
        }
    }

    // MARK: - EvaluationResult new fields

    func test_evaluationResult_usedFallback_default() {
        let r = EvaluationResult(id: "1", isCorrect: true, latencyMs: 10)
        XCTAssertFalse(r.usedFallback)
        XCTAssertNil(r.confidence)
        XCTAssertNil(r.itemErrorCount)
    }

    func test_evaluationResult_usedFallback_set() {
        let r = EvaluationResult(id: "1", isCorrect: true, latencyMs: 10, usedFallback: true, confidence: "certain", itemErrorCount: 3)
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
        let metrics = EvaluationMetrics(totalCases: 3, passRate: 2.0/3.0, errorCount: 0, latencyMsMean: 10, latencyMsP90: 10)
        let report = EvaluationReport(featureName: "Test", metrics: metrics, results: results, passedBaseline: true)
        XCTAssertEqual(report.passCount, 2)
    }
}
