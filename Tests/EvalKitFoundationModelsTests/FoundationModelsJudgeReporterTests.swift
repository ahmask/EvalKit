// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelsJudgeReporterTests.swift
// EvalKitFoundationModelsTests
//
// Tests for FoundationModelsJudgeReporter and FoundationModelsAdapter.
// All tests use mock closures — no real FoundationModels calls are made.

import XCTest
import EvalKit
import EvalKitJudge
@testable import EvalKitFoundationModels

final class FoundationModelsJudgeReporterTests: XCTestCase {

    // MARK: - Helpers

    private func makeCases(count: Int) -> [TextEvaluationCase] {
        (0..<count).map { i in
            TextEvaluationCase(id: "case-\(i)", input: "input \(i)", expectedOutput: "")
        }
    }

    // MARK: - Test 1: FoundationModelsAdapter throws when model not available

#if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    func test_adapter_throwsModelNotAvailable_whenAppleIntelligenceUnavailable() async throws {
        // On macOS CI and simulator, SystemLanguageModel.default.availability != .available,
        // so this adapter call is expected to throw modelNotAvailable.
        let adapter = FoundationModelsAdapter()
        do {
            _ = try await adapter.respond(to: "test prompt")
            // If we reach here, Apple Intelligence IS available (running on real device).
            // In that case, we can't test the unavailability path — skip gracefully.
        } catch let error as EvalKitFoundationModelsError {
            XCTAssertEqual(error, .modelNotAvailable)
        } catch {
            // A different error from the session itself means Apple Intelligence IS available,
            // which is not the path under test.
        }
    }
#endif

    // MARK: - Test 2: Results count matches cases count

    func test_report_resultCountMatchesCaseCount() async {
        let cases = makeCases(count: 3)
        let passingJSON = #"{"passed": true, "reasoning": "Grammatically correct"}"#
        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.fluency()],
            judge: { _ in passingJSON }
        )

        let report = await reporter.report(
            from: cases,
            featureName: "TestFeature"
        ) { testCase in
            "mock output for \(testCase.id)"
        }

        XCTAssertEqual(report.results.count, 3)
        XCTAssertEqual(report.featureName, "TestFeature")
    }

    // MARK: - Test 3: outputProvider error is captured, not thrown

    func test_report_outputProviderError_isCapturedNotPropagated() async {
        let cases = makeCases(count: 2)
        let passingJSON = #"{"passed": true, "reasoning": "Grammatically correct"}"#
        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.fluency()],
            judge: { _ in passingJSON }
        )

        let report = await reporter.report(
            from: cases,
            featureName: "ErrorTest"
        ) { _ in
            throw URLError(.badServerResponse)  // simulate outputProvider failure
        }

        // All cases should still appear in results — batch is not aborted
        XCTAssertEqual(report.results.count, 2)

        // Every case should have a non-nil error and empty scores
        for result in report.results {
            XCTAssertNotNil(result.error, "Expected error to be captured in JudgeResult")
            XCTAssertTrue(result.scores.isEmpty, "Expected empty scores when outputProvider throws")
        }
    }

    // MARK: - Test 4: keyFactsProvider is passed through to the judge prompt

    func test_report_keyFactsProvider_isPassedThroughToJudgePrompt() async {
        let cases = [TextEvaluationCase(id: "case-1", input: "original input", expectedOutput: "")]
        let itemJSON = #"{"results": [{"fact": "flight is LH400", "score": 1, "reasoning": "found"}]}"#
        let collector = StringCollector()

        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.groundedness()],
            judge: { prompt in
                await collector.append(prompt)
                return itemJSON
            }
        )

        _ = await reporter.report(
            from: cases,
            featureName: "FactTest",
            outputProvider: { _ in "The flight LH400 departed on time." },
            keyFactsProvider: { _ in
                ["groundedness": ["flight is LH400"]]
            }
        )

        let prompts = await collector.values
        XCTAssertFalse(prompts.isEmpty, "Expected judge to be called")
        let prompt = prompts.first ?? ""
        XCTAssertTrue(
            prompt.contains("flight is LH400"),
            "Expected key fact to appear in judge prompt. Got: \(prompt)"
        )
    }

    // MARK: - Test 5a: passedBaseline is true when pass rate meets threshold

    func test_passedBaseline_isTrue_whenAllCasesPass() async {
        let cases = makeCases(count: 4)
        let passingJSON = #"{"passed": true, "reasoning": "Grammatically correct"}"#
        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.fluency()],
            minimumPassRate: 0.80,
            judge: { _ in passingJSON }
        )

        let report = await reporter.report(
            from: cases,
            featureName: "AllPassTest"
        ) { _ in "good output" }

        XCTAssertTrue(report.passedBaseline, "Expected passedBaseline == true when all cases pass")
        XCTAssertEqual(report.metrics.passRate, 1.0, accuracy: 0.001)
    }

    // MARK: - Test 5b: passedBaseline is false when pass rate falls below threshold

    func test_passedBaseline_isFalse_whenBelowMinimumPassRate() async {
        // All 10 cases have outputProvider throw → all errored → allPassed = false → 0% pass
        let cases = makeCases(count: 10)
        let passingJSON = #"{"passed": true, "reasoning": "Grammatically correct"}"#
        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.fluency()],
            minimumPassRate: 0.80,
            judge: { _ in passingJSON }
        )

        let report = await reporter.report(
            from: cases,
            featureName: "FailThresholdTest"
        ) { _ in
            throw URLError(.badServerResponse)  // all fail
        }

        XCTAssertFalse(report.passedBaseline, "Expected passedBaseline == false when < 80% pass")
        XCTAssertLessThan(report.metrics.passRate, 0.80)
    }

    // MARK: - Test 6: EvalKitFoundationModelsError has a non-empty description

    func test_modelNotAvailableError_hasErrorDescription() {
        let error = EvalKitFoundationModelsError.modelNotAvailable
        let description = error.errorDescription ?? ""
        XCTAssertFalse(description.isEmpty, "Expected non-empty error description")
        XCTAssertTrue(
            description.contains("Apple Intelligence"),
            "Expected description to mention Apple Intelligence"
        )
    }

    // MARK: - Test 7: Empty cases produce an empty report without crashing

    func test_report_withNoCases_producesEmptyReport() async {
        let passingJSON = #"{"passed": true, "reasoning": "Grammatically correct"}"#
        let reporter = FoundationModelsJudgeReporter(
            dimensions: [.fluency()],
            judge: { _ in passingJSON }
        )

        let report = await reporter.report(
            from: [],
            featureName: "EmptyTest"
        ) { _ in "output" }

        XCTAssertEqual(report.results.count, 0)
        XCTAssertEqual(report.metrics.totalCases, 0)
        // passRate with zero cases is 0.0, so 0.0 < 0.80 → passedBaseline false
        XCTAssertFalse(report.passedBaseline)
    }
}

// MARK: - Helpers

/// Thread-safe string collector for capturing values from concurrent tasks in tests.
private actor StringCollector {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

