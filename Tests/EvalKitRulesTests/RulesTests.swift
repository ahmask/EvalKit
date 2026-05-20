// EvalKit — all processing is on-device. No data leaves the device.
//
// RulesTests.swift
// EvalKitRulesTests

import XCTest
import EvalKit
@testable import EvalKitRules

final class RulesTests: XCTestCase {

    // MARK: - MaxSentencesRule

    func test_maxSentences_passesAtLimit() {
        let rule = MaxSentencesRule(maximum: 2)
        XCTAssertTrue(rule.evaluate(output: "Hello. World.", context: [:]))
    }

    func test_maxSentences_failsAboveLimit() {
        let rule = MaxSentencesRule(maximum: 1)
        XCTAssertFalse(rule.evaluate(output: "Hello. How are you?", context: [:]))
    }

    func test_maxSentences_singleSentenceNoTerminator() {
        // Text with no punctuation is counted as 1 sentence
        let rule = MaxSentencesRule(maximum: 1)
        XCTAssertTrue(rule.evaluate(output: "Hello there", context: [:]))
    }

    func test_maxSentences_failureDescriptionIncludesActualCount() {
        let rule = MaxSentencesRule(maximum: 1)
        let msg = rule.failureDescription(for: "Hello. How are you?", context: [:])
        XCTAssertTrue(msg.contains("2"), "Expected actual count in message: \(msg)")
        XCTAssertTrue(msg.contains("1"), "Expected max in message: \(msg)")
    }

    // MARK: - MaxWordsRule

    func test_maxWords_passesAtLimit() {
        // "one two three" = 3 words
        let rule = MaxWordsRule(maximum: 3)
        XCTAssertTrue(rule.evaluate(output: "one two three", context: [:]))
    }

    func test_maxWords_failsAboveLimit() {
        let rule = MaxWordsRule(maximum: 2)
        XCTAssertFalse(rule.evaluate(output: "one two three", context: [:]))
    }

    func test_maxWords_failureDescriptionIncludesActualCount() {
        let rule = MaxWordsRule(maximum: 2)
        let msg = rule.failureDescription(for: "one two three", context: [:])
        XCTAssertTrue(msg.contains("3"), "Expected actual word count: \(msg)")
        XCTAssertTrue(msg.contains("2"), "Expected max in message: \(msg)")
    }

    // MARK: - ValidJSONRule

    func test_validJSON_passesValidJSON() {
        let rule = ValidJSONRule()
        XCTAssertTrue(rule.evaluate(output: #"{"key": "value"}"#, context: [:]))
    }

    func test_validJSON_failsInvalidJSON() {
        let rule = ValidJSONRule()
        XCTAssertFalse(rule.evaluate(output: "not json", context: [:]))
    }

    func test_validJSON_passesWhenRequiredKeysPresent() {
        let rule = ValidJSONRule(requiredKeys: ["items", "destination"])
        let json = #"{"items": [], "destination": "Munich"}"#
        XCTAssertTrue(rule.evaluate(output: json, context: [:]))
    }

    func test_validJSON_failsWhenRequiredKeysMissing() {
        let rule = ValidJSONRule(requiredKeys: ["items", "destination"])
        let json = #"{"items": []}"#
        XCTAssertFalse(rule.evaluate(output: json, context: [:]))
    }

    func test_validJSON_failureDescriptionListsMissingKeys() {
        let rule = ValidJSONRule(requiredKeys: ["items", "destination"])
        let msg = rule.failureDescription(for: #"{"items": []}"#, context: [:])
        XCTAssertTrue(msg.contains("destination"), "Expected missing key in message: \(msg)")
    }

    // MARK: - AllowedItemsRule

    func test_allowedItems_allAllowedPasses() {
        let allowed: [String: [String]] = ["clothing": ["t-shirt", "jeans"]]
        let rule = AllowedItemsRule(allowedItems: allowed) { output in
            // Parse JSON to get items
            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
            else { return [:] }
            return json
        }
        let json = #"{"clothing": ["t-shirt", "jeans"]}"#
        XCTAssertTrue(rule.evaluate(output: json, context: [:]))
    }

    func test_allowedItems_unknownItemFails() {
        let allowed: [String: [String]] = ["clothing": ["t-shirt", "jeans"]]
        let rule = AllowedItemsRule(allowedItems: allowed) { output in
            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
            else { return [:] }
            return json
        }
        let json = #"{"clothing": ["t-shirt", "unknown_item"]}"#
        XCTAssertFalse(rule.evaluate(output: json, context: [:]))
    }

    func test_allowedItems_failureDescriptionMentionsViolatingItem() {
        let allowed: [String: [String]] = ["clothing": ["t-shirt"]]
        let rule = AllowedItemsRule(allowedItems: allowed) { output in
            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
            else { return [:] }
            return json
        }
        let json = #"{"clothing": ["unknown_item"]}"#
        let msg = rule.failureDescription(for: json, context: [:])
        XCTAssertTrue(msg.contains("unknown_item"), "Expected item name in message: \(msg)")
    }

    // MARK: - LanguageMatchRule

    func test_languageMatch_correctLanguagePasses() {
        let rule = LanguageMatchRule(expectedLanguage: "en")
        // English text should be detected as English
        XCTAssertTrue(rule.evaluate(output: "Hello, how are you today?", context: [:]))
    }

    func test_languageMatch_wrongLanguageFails() {
        let rule = LanguageMatchRule(expectedLanguage: "de")
        // English text should not match German
        XCTAssertFalse(rule.evaluate(output: "Hello, how are you today?", context: [:]))
    }

    // MARK: - RegexRule

    func test_regex_mustMatch_trueWhenMatched() {
        let rule = RegexRule(pattern: "^Hello", name: "starts_with_hello", mustMatch: true)
        XCTAssertTrue(rule.evaluate(output: "Hello world", context: [:]))
    }

    func test_regex_mustMatch_falseWhenNotMatched() {
        let rule = RegexRule(pattern: "^Hello", name: "starts_with_hello", mustMatch: true)
        XCTAssertFalse(rule.evaluate(output: "Hi world", context: [:]))
    }

    func test_regex_mustNotMatch_trueWhenNotMatched() {
        let rule = RegexRule(pattern: "\\d{3}-\\d{4}", name: "no_phone_number", mustMatch: false)
        XCTAssertTrue(rule.evaluate(output: "Call us at our office", context: [:]))
    }

    func test_regex_mustNotMatch_falseWhenMatched() {
        let rule = RegexRule(pattern: "\\d{3}-\\d{4}", name: "no_phone_number", mustMatch: false)
        XCTAssertFalse(rule.evaluate(output: "Call 555-1234 for details", context: [:]))
    }

    func test_regex_invalidPatternFails() {
        let rule = RegexRule(pattern: "[invalid(", name: "bad_pattern", mustMatch: true)
        XCTAssertFalse(rule.evaluate(output: "anything", context: [:]))
    }

    // MARK: - RulesReporter

    func test_rulesReporter_passRateCorrect() async {
        let cases = [
            TextEvaluationCase(id: "1", input: "hello", expectedOutput: ""),
            TextEvaluationCase(id: "2", input: "hi", expectedOutput: ""),
            TextEvaluationCase(id: "3", input: "hey", expectedOutput: ""),
            TextEvaluationCase(id: "4", input: "greet", expectedOutput: ""),
        ]

        let rule = MaxWordsRule(maximum: 3)
        let reporter = RulesReporter(rules: [rule], minimumPassRate: 0.75)

        let report = await reporter.report(from: cases, featureName: "Test") { testCase in
            // Cases 1-3 pass (≤3 words output), case 4 fails
            switch testCase.id {
            case "4": return "one two three four"  // 4 words — fails
            default:  return "one two three"         // 3 words — passes
            }
        }

        // 3/4 pass = 0.75
        XCTAssertEqual(report.passRate, 0.75, accuracy: 0.001)
        XCTAssertTrue(report.passedBaseline)
    }

    func test_rulesReporter_violationSummaryCountsCorrect() async {
        let cases = [
            TextEvaluationCase(id: "1", input: "a", expectedOutput: ""),
            TextEvaluationCase(id: "2", input: "b", expectedOutput: ""),
        ]

        let rule = MaxWordsRule(maximum: 1)
        let reporter = RulesReporter(rules: [rule])

        let report = await reporter.report(from: cases, featureName: "Test") { _ in
            "too many words here"  // Both cases fail the word count rule
        }

        XCTAssertEqual(report.violationSummary["max_words"], 2)
    }

    func test_rulesReporter_outputProviderThrows_recordedAsError() async {
        let cases = [TextEvaluationCase(id: "1", input: "x", expectedOutput: "")]
        let reporter = RulesReporter(rules: [MaxWordsRule(maximum: 10)])

        struct TestError: Error { let message = "provider failed" }
        let report = await reporter.report(from: cases, featureName: "Test") { _ in
            throw TestError()
        }

        XCTAssertEqual(report.passRate, 0.0)
        XCTAssertFalse(report.results.first!.passed)
        XCTAssertFalse(report.results.first!.violations.isEmpty)
    }
}
