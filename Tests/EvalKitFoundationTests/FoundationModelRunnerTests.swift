// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelRunnerTests.swift
// EvalKitFoundationTests

import XCTest
import EvalKit
@testable import EvalKitFoundation

final class FoundationModelRunnerTests: XCTestCase {

    // MARK: - isCorrect via score

    func test_run_withScoreAtOrAboveOne_isCorrect() async throws {
        let runner = FoundationModelRunner { _ in
            .init(predicted: "positive", score: 1.0)
        }
        let testCase = FoundationModelCase(id: "1", input: "great product", expectedOutput: "positive")

        let result = try await runner.run(testCase)

        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.score, 1.0)
    }

    func test_run_withScoreBelowOne_isNotCorrect() async throws {
        let runner = FoundationModelRunner { _ in
            .init(predicted: "positive", score: 0.5)
        }
        let testCase = FoundationModelCase(id: "2", input: "okay product", expectedOutput: "positive")

        let result = try await runner.run(testCase)

        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.score, 0.5)
    }

    // MARK: - isCorrect via substring match (no score)

    func test_run_withoutScore_substringMatch_isCorrect() async throws {
        // LLM returns exact label
        let runner = FoundationModelRunner { _ in
            .init(predicted: "baggage")
        }
        let testCase = FoundationModelCase(id: "3", input: "my bag is lost", expectedOutput: "baggage")

        let result = try await runner.run(testCase)

        XCTAssertTrue(result.isCorrect)
    }

    func test_run_withoutScore_substringMatch_caseInsensitive() async throws {
        // LLM returns label with different casing (e.g. "Baggage")
        let runner = FoundationModelRunner { _ in
            .init(predicted: "Baggage")
        }
        let testCase = FoundationModelCase(id: "4", input: "my bag is lost", expectedOutput: "baggage")

        let result = try await runner.run(testCase)

        XCTAssertTrue(result.isCorrect)
    }

    func test_run_withoutScore_noMatch_isNotCorrect() async throws {
        let runner = FoundationModelRunner { _ in
            .init(predicted: "checkin")
        }
        let testCase = FoundationModelCase(id: "5", input: "my bag is lost", expectedOutput: "baggage")

        let result = try await runner.run(testCase)

        XCTAssertFalse(result.isCorrect)
    }

    // MARK: - Hallucination flag

    func test_run_propagatesHallucinationFlag() async throws {
        let runner = FoundationModelRunner { _ in
            .init(predicted: "inventedCategory", hallucinationFlag: true)
        }
        let testCase = FoundationModelCase(id: "6", input: "test", expectedOutput: "baggage")

        let result = try await runner.run(testCase)

        XCTAssertTrue(result.hallucinationFlag)
    }

    // MARK: - Secondary score

    func test_run_propagatesSecondaryScore() async throws {
        let runner = FoundationModelRunner { _ in
            .init(predicted: "x", score: 0.8, secondaryScore: 0.6)
        }
        let testCase = FoundationModelCase(id: "7", input: "test", expectedOutput: "x")

        let result = try await runner.run(testCase)

        XCTAssertEqual(result.secondaryScore, 0.6)
    }

    // MARK: - Error handling

    func test_run_throwingGenerate_capturesErrorAndRecordsLatency() async throws {
        struct GenerateError: Error {}
        let runner = FoundationModelRunner { _ in throw GenerateError() }
        let testCase = FoundationModelCase(id: "8", input: "test", expectedOutput: "cat")

        let result = try await runner.run(testCase)

        XCTAssertFalse(result.isCorrect)
        XCTAssertNil(result.predictedLabel)
        XCTAssertNotNil(result.error)
        XCTAssertGreaterThanOrEqual(result.latencyMs, 0)
    }

    // MARK: - Latency and ID propagation

    func test_run_recordsLatencyAndPropagatesId() async throws {
        let runner = FoundationModelRunner { _ in .init(predicted: "label") }
        let testCase = FoundationModelCase(id: "run-42", input: "text", expectedOutput: "label")

        let result = try await runner.run(testCase)

        XCTAssertEqual(result.id, "run-42")
        XCTAssertGreaterThanOrEqual(result.latencyMs, 0)
    }
}
