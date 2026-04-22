// EvalKit — all processing is on-device. No data leaves the device.
//
// CoreMLLatencyRunnerTests.swift
// EvalKitCoreMLTests

import XCTest
import EvalKit
@testable import EvalKitCoreML

final class CoreMLLatencyRunnerTests: XCTestCase {

    // MARK: - Correct prediction

    func test_run_correctPrediction() async throws {
        let runner = CoreMLLatencyRunner { _ in "cat" }
        let testCase = CoreMLTextCase(id: "1", input: "fluffy animal", expectedOutput: "cat")

        let result = try await runner.run(testCase)

        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.predictedLabel, "cat")
        XCTAssertEqual(result.expectedLabel, "cat")
        XCTAssertNil(result.error)
        XCTAssertGreaterThanOrEqual(result.latencyMs, 0)
    }

    // MARK: - Incorrect prediction

    func test_run_incorrectPrediction() async throws {
        let runner = CoreMLLatencyRunner { _ in "dog" }
        let testCase = CoreMLTextCase(id: "2", input: "fluffy animal", expectedOutput: "cat")

        let result = try await runner.run(testCase)

        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.predictedLabel, "dog")
        XCTAssertEqual(result.expectedLabel, "cat")
        XCTAssertNil(result.error)
    }

    // MARK: - Error handling

    func test_run_throwingClassifier_capturesErrorAndRecordsLatency() async throws {
        struct ClassifyError: Error {}
        let runner = CoreMLLatencyRunner { _ in throw ClassifyError() }
        let testCase = CoreMLTextCase(id: "3", input: "unknown", expectedOutput: "cat")

        let result = try await runner.run(testCase)

        XCTAssertFalse(result.isCorrect)
        XCTAssertNil(result.predictedLabel)
        XCTAssertNotNil(result.error)
        // Latency should still be recorded (runner captures it before catching)
        XCTAssertGreaterThanOrEqual(result.latencyMs, 0)
    }

    // MARK: - Latency is measured

    func test_run_recordsNonNegativeLatency() async throws {
        let runner = CoreMLLatencyRunner { _ in "label" }
        let testCase = CoreMLTextCase(id: "4", input: "text", expectedOutput: "label")

        let result = try await runner.run(testCase)

        XCTAssertGreaterThanOrEqual(result.latencyMs, 0)
    }

    // MARK: - ID propagation

    func test_run_propagatesId() async throws {
        let runner = CoreMLLatencyRunner { _ in "A" }
        let testCase = CoreMLTextCase(id: "test-id-42", input: "x", expectedOutput: "A")

        let result = try await runner.run(testCase)

        XCTAssertEqual(result.id, "test-id-42")
    }
}
