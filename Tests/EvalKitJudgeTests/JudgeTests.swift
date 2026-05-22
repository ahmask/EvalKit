// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeTests.swift
// EvalKitJudgeTests

import XCTest
import EvalKit
@testable import EvalKitJudge

final class JudgeTests: XCTestCase {

    // MARK: 1 — Binary prompt substitution

    func test_binaryPromptSubstitution() {
        let dim = JudgeDimension.fluency()
        let prompt = dim.buildPrompt(input: "What is Paris?", output: "Paris is the capital of France.")
        XCTAssertTrue(prompt.contains("What is Paris?"), "Expected {input} replaced")
        XCTAssertTrue(prompt.contains("Paris is the capital of France."), "Expected {output} replaced")
        XCTAssertFalse(prompt.contains("{input}"), "Expected no leftover {input}")
        XCTAssertFalse(prompt.contains("{output}"), "Expected no leftover {output}")
        XCTAssertFalse(prompt.contains("{language_context}"), "Expected no leftover {language_context}")
    }

    // MARK: 2 — Fluency with language: prompt contains " in de"

    func test_fluencyWithLanguage_containsForGerman() {
        let dim = JudgeDimension.fluency()
        let prompt = dim.buildPrompt(input: "prompt", output: "response", language: "de")
        XCTAssertTrue(prompt.contains(" in de"), "Expected ' in de' in fluency prompt: \(prompt)")
        XCTAssertFalse(prompt.contains("{language_context}"), "Expected no leftover placeholder")
    }

    // MARK: 3 — Fluency without language: {language_context} becomes empty string

    func test_fluencyWithoutLanguage_languageContextEmpty() {
        let dim = JudgeDimension.fluency()
        let prompt = dim.buildPrompt(input: "prompt", output: "response")
        XCTAssertFalse(prompt.contains("{language_context}"), "Expected no leftover placeholder")
        // The checker line should not have trailing text from {language_context}
        XCTAssertTrue(prompt.contains("You are a grammar and language quality checker.") ||
                      prompt.contains("You are a grammar and language quality checker\n"),
                      "Expected checker line without language suffix: \(prompt)")
    }

    // MARK: 4 — Binary JSON {"passed": true} → score = 1.0

    func test_binaryJSON_passedTrue_scoreIsOne() async {
        let dim = JudgeDimension.fluency()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            #"{"passed": true, "reasoning": "Grammatically correct"}"#
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "fluency")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 1.0, accuracy: 0.001)
        XCTAssertEqual(score!.reasoning, "Grammatically correct")
        XCTAssertEqual(score!.passingThreshold, 1.0, accuracy: 0.001)
    }

    // MARK: 5 — Binary JSON {"passed": false} → score = 0.0

    func test_binaryJSON_passedFalse_scoreIsZero() async {
        let dim = JudgeDimension.fluency()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            #"{"passed": false, "reasoning": "Grammar issues found"}"#
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "fluency")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 0.0, accuracy: 0.001)
    }

    // MARK: 6 — Holistic prompt substitution

    func test_holisticPromptSubstitution() {
        let dim = JudgeDimension.tone()
        let prompt = dim.buildPrompt(input: "What is my booking?", output: "Your booking is confirmed.")
        XCTAssertTrue(prompt.contains("What is my booking?"), "Expected {input} replaced")
        XCTAssertTrue(prompt.contains("Your booking is confirmed."), "Expected {output} replaced")
        XCTAssertFalse(prompt.contains("{input}"), "Expected no leftover placeholder")
        XCTAssertFalse(prompt.contains("{output}"), "Expected no leftover placeholder")
    }

    // MARK: 7 — Holistic JSON parsed correctly

    func test_holisticJSON_parsedCorrectly() async {
        let dim = JudgeDimension.tone()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            #"{"score": 4, "reasoning": "Good tone"}"#
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "tone")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 4.0, accuracy: 0.001)
        XCTAssertEqual(score!.reasoning, "Good tone")
    }

    // MARK: 8 — Item-by-item prompt substitution

    func test_itemByItemPromptSubstitution() {
        let dim = JudgeDimension(
            name: "recall",
            promptTemplate: "Facts: {key_facts}\nInput: {input}\nOutput: {output}",
            scoringPattern: .itemByItem(keyFacts: ["Fact one", "Fact two"])
        )
        let prompt = dim.buildPrompt(input: "context", output: "summary")
        XCTAssertTrue(prompt.contains("1. Fact one"), "Expected numbered fact list")
        XCTAssertTrue(prompt.contains("2. Fact two"), "Expected numbered fact list")
        XCTAssertFalse(prompt.contains("{key_facts}"), "Expected no leftover placeholder")
    }

    // MARK: 9 — Item-by-item JSON parsed correctly

    func test_itemByItemJSON_parsedCorrectly() async {
        let dim = JudgeDimension(
            name: "recall",
            promptTemplate: JudgeDimension.recall().promptTemplate,
            scoringPattern: .itemByItem(keyFacts: ["fact A", "fact B"])
        )
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            #"{"results": [{"fact": "fact A", "score": 1, "reasoning": "found"}, {"fact": "fact B", "score": 0, "reasoning": "missing"}]}"#
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "recall")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 0.5, accuracy: 0.001)
        XCTAssertEqual(score!.factScores.count, 2)
        XCTAssertEqual(score!.factScores[0].score, 1)
        XCTAssertEqual(score!.factScores[1].score, 0)
    }

    // MARK: 10 — Malformed JSON binary → score = 0.0, reasoning contains "Failed to parse"

    func test_malformedJSON_binary_scoreIsZero() async {
        let dim = JudgeDimension.fluency()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            "this is not json at all"
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "fluency")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 0.0, accuracy: 0.001)
        XCTAssertTrue(score!.reasoning.contains("Failed to parse"), "Expected parse error in reasoning: \(score!.reasoning)")
    }

    // MARK: 11 — Malformed JSON holistic → score = 1.0, reasoning contains "Failed to parse"

    func test_malformedJSON_holistic_scoreIsOne() async {
        let dim = JudgeDimension.tone()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            "not json"
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "tone")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 1.0, accuracy: 0.001)
        XCTAssertTrue(score!.reasoning.contains("Failed to parse"), "Expected parse error in reasoning")
    }

    // MARK: 12 — Malformed JSON item-by-item → score = 0.0, factScores empty

    func test_malformedJSON_itemByItem_scoreIsZero() async {
        let dim = JudgeDimension(
            name: "groundedness",
            promptTemplate: JudgeDimension.groundedness().promptTemplate,
            scoringPattern: .itemByItem(keyFacts: ["fact"])
        )
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            "bad json"
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "groundedness")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 0.0, accuracy: 0.001)
        XCTAssertTrue(score!.factScores.isEmpty)
    }

    // MARK: 13 — Holistic score out of range → returned as 1.0 (non-numeric parse fallback)

    func test_scoreOutOfRange_holisticFallback() async {
        let dim = JudgeDimension.safety()
        let runner = LLMJudgeRunner(dimensions: [dim]) { _ in
            #"{"score": "invalid", "reasoning": "bad"}"#
        }
        let result = await runner.evaluate(caseId: "1", input: "input", output: "output")
        let score = result.score(for: "safety")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!.score, 1.0, "Expected fallback score for non-numeric value")
    }

    // MARK: 14 — JudgeScore.passed for all three patterns

    func test_judgeScore_passed_binaryThreshold() {
        let passing = JudgeScore(dimension: "fluency", score: 1.0, reasoning: "", passingThreshold: 1.0)
        XCTAssertTrue(passing.passed)
        let failing = JudgeScore(dimension: "fluency", score: 0.0, reasoning: "", passingThreshold: 1.0)
        XCTAssertFalse(failing.passed)
    }

    func test_judgeScore_passed_holisticThreshold() {
        let passing = JudgeScore(dimension: "tone", score: 3.5, reasoning: "", passingThreshold: 3.0)
        XCTAssertTrue(passing.passed)
        let failing = JudgeScore(dimension: "tone", score: 2.5, reasoning: "", passingThreshold: 3.0)
        XCTAssertFalse(failing.passed)
    }

    func test_judgeScore_passed_itemByItemThreshold() {
        let passing = JudgeScore(dimension: "recall", score: 0.75, reasoning: "", passingThreshold: 0.75)
        XCTAssertTrue(passing.passed)
        let failing = JudgeScore(dimension: "recall", score: 0.5, reasoning: "", passingThreshold: 0.75)
        XCTAssertFalse(failing.passed)
    }

    // MARK: 15 — JudgeMetrics.compute: passRate, averageScore, factPassRates

    func test_judgeMetrics_passRateAndAverageScore() {
        let results = [
            JudgeResult(caseId: "1", scores: [JudgeScore(dimension: "tone", score: 4.0, reasoning: "", passingThreshold: 3.0)], latencyMs: 100),
            JudgeResult(caseId: "2", scores: [JudgeScore(dimension: "tone", score: 2.0, reasoning: "", passingThreshold: 3.0)], latencyMs: 100),
        ]
        let metrics = JudgeMetrics.compute(from: results, passingThreshold: 3.0, itemByItemPassingThreshold: 0.75)
        let dimMetrics = metrics.dimensionMetrics.first { $0.dimension == "tone" }
        XCTAssertNotNil(dimMetrics)
        XCTAssertEqual(dimMetrics!.averageScore, 3.0, accuracy: 0.001)
        XCTAssertEqual(dimMetrics!.passRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(metrics.passRate, 0.5, accuracy: 0.001)
    }

    func test_judgeMetrics_factPassRates() {
        let factScores1 = [
            JudgeScore.FactScore(fact: "fact A", score: 1, reasoning: ""),
            JudgeScore.FactScore(fact: "fact B", score: 0, reasoning: ""),
        ]
        let factScores2 = [
            JudgeScore.FactScore(fact: "fact A", score: 1, reasoning: ""),
            JudgeScore.FactScore(fact: "fact B", score: 1, reasoning: ""),
        ]
        let results = [
            JudgeResult(caseId: "1", scores: [JudgeScore(dimension: "recall", score: 0.5, reasoning: "", passingThreshold: 0.75, factScores: factScores1)], latencyMs: 100),
            JudgeResult(caseId: "2", scores: [JudgeScore(dimension: "recall", score: 1.0, reasoning: "", passingThreshold: 0.75, factScores: factScores2)], latencyMs: 100),
        ]
        let metrics = JudgeMetrics.compute(from: results, passingThreshold: 3.0, itemByItemPassingThreshold: 0.75)
        let dimMetrics = metrics.dimensionMetrics.first { $0.dimension == "recall" }
        XCTAssertNotNil(dimMetrics)
        XCTAssertEqual(dimMetrics!.factPassRates["fact A"] ?? -1, 1.0, accuracy: 0.001)
        XCTAssertEqual(dimMetrics!.factPassRates["fact B"] ?? -1, 0.5, accuracy: 0.001)
    }

    // MARK: 16 — keyFactsOverride uses override instead of defaults

    func test_keyFactsOverride_usesOverrideInsteadOfDefaults() async {
        nonisolated(unsafe) var capturedPrompt = ""
        let dim = JudgeDimension(
            name: "recall",
            promptTemplate: "Facts: {key_facts}\nInput: {input}\nOutput: {output}",
            scoringPattern: .itemByItem(keyFacts: ["default fact"])
        )
        let runner = LLMJudgeRunner(dimensions: [dim]) { prompt in
            capturedPrompt = prompt
            return #"{"results": [{"fact": "override fact", "score": 1, "reasoning": "found"}]}"#
        }
        _ = await runner.evaluate(
            caseId: "1",
            input: "input",
            output: "output",
            keyFactsOverride: ["recall": ["override fact"]]
        )
        XCTAssertTrue(capturedPrompt.contains("override fact"), "Expected override fact in prompt")
        XCTAssertFalse(capturedPrompt.contains("default fact"), "Expected default fact NOT in prompt")
    }

    // MARK: 17 — outputProvider throws → error captured, reporter returns complete report

    func test_outputProviderThrows_reporterReturnsCompleteReport() async {
        let cases = [TextEvaluationCase(id: "1", input: "input", expectedOutput: "")]
        let reporter = LLMJudgeReporter(
            dimensions: [.safety()],
            minimumPassRate: 0.80
        ) { _ in
            #"{"score": 5, "reasoning": "safe"}"#
        }
        struct TestError: Error {}
        let report = await reporter.report(from: cases, featureName: "Test") { _ in
            throw TestError()
        }
        XCTAssertNotNil(report)
        XCTAssertEqual(report.results.count, 1)
        XCTAssertNotNil(report.results.first?.error)
        XCTAssertFalse(report.passedBaseline)
    }

    // MARK: 18 — All default prompts contain {input} and {output} placeholders

    func test_allDefaultPrompts_containInputAndOutput() {
        let dimensions: [JudgeDimension] = [
            .fluency(), .groundedness(), .recall(), .tone(), .safety(), .coherence(), .faithfulness()
        ]
        for dim in dimensions {
            XCTAssertTrue(dim.promptTemplate.contains("{input}"),
                          "\(dim.name) prompt missing {input}")
            XCTAssertTrue(dim.promptTemplate.contains("{output}"),
                          "\(dim.name) prompt missing {output}")
        }
    }

    // MARK: 19 — Item-by-item default prompts contain {key_facts}

    func test_itemByItemDefaultPrompts_containKeyFacts() {
        let dimensions: [JudgeDimension] = [
            .fluency(), .groundedness(), .recall(), .tone(), .safety(), .coherence(), .faithfulness()
        ]
        for dim in dimensions {
            if case .itemByItem = dim.scoringPattern {
                XCTAssertTrue(dim.promptTemplate.contains("{key_facts}"),
                              "\(dim.name) item-by-item prompt missing {key_facts}")
            }
        }
    }

    // MARK: 20 — Binary default prompts do NOT contain {score} placeholder

    func test_binaryDefaultPrompts_doNotContainScorePlaceholder() {
        let dimensions: [JudgeDimension] = [
            .fluency(), .groundedness(), .recall(), .tone(), .safety(), .coherence(), .faithfulness()
        ]
        for dim in dimensions {
            if case .binary = dim.scoringPattern {
                XCTAssertFalse(dim.promptTemplate.contains("{score}"),
                               "\(dim.name) binary prompt should not contain {score}")
            }
        }
    }

    // MARK: 21 — LLMJudgeReporter passedBaseline: true at 0.90 with minimum 0.80, false at 0.75

    func test_reporter_passedBaseline_trueAtHighPassRate() async {
        let cases = (1...10).map { TextEvaluationCase(id: "\($0)", input: "input", expectedOutput: "") }
        let reporter = LLMJudgeReporter(
            dimensions: [.safety()],
            minimumPassRate: 0.80
        ) { _ in
            #"{"score": 5, "reasoning": "safe"}"#
        }
        let report = await reporter.report(from: cases, featureName: "Test") { _ in "output" }
        XCTAssertTrue(report.passedBaseline)
        XCTAssertGreaterThanOrEqual(report.metrics.passRate, 0.80)
    }

    func test_reporter_passedBaseline_falseAtLowPassRate() async {
        let cases = (1...4).map { TextEvaluationCase(id: "\($0)", input: "input", expectedOutput: "") }
        let reporter = LLMJudgeReporter(
            dimensions: [.safety()],
            minimumPassRate: 0.80,
            passingThreshold: 3.0
        ) { _ in
            #"{"score": 2, "reasoning": "unsafe"}"#
        }
        let report = await reporter.report(from: cases, featureName: "Test") { _ in "output" }
        XCTAssertFalse(report.passedBaseline)
        XCTAssertLessThan(report.metrics.passRate, 0.80)
    }
}
