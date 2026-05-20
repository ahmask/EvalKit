// EvalKit — all processing is on-device. No data leaves the device.
//
// RetrievalTests.swift
// EvalKitRetrievalTests

import XCTest
import EvalKit
@testable import EvalKitRetrieval

final class RetrievalTests: XCTestCase {

    // MARK: - JaccardSimilarity

    func test_jaccard_exactMatch() {
        let score = JaccardSimilarity.compute(
            predicted: ["topic1", "topic2"],
            expected:  ["topic1", "topic2"]
        )
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_jaccard_noOverlap() {
        let score = JaccardSimilarity.compute(
            predicted: ["topic1"],
            expected:  ["topic2"]
        )
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    func test_jaccard_partialOverlap() {
        // intersection: {topic1, topic2} = 2, union: {topic1,topic2,topic3,topic4} = 4
        let score = JaccardSimilarity.compute(
            predicted: ["topic1", "topic2", "topic3"],
            expected:  ["topic1", "topic2", "topic4"]
        )
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    func test_jaccard_bothEmpty() {
        XCTAssertEqual(JaccardSimilarity.compute(predicted: [], expected: []), 0.0)
    }

    func test_jaccard_commaSeparatedString() {
        let score = JaccardSimilarity.compute(
            predicted: "topic1,topic2,topic3",
            expected:  "topic1,topic2,topic4"
        )
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    // MARK: - PositionSimilarity

    func test_position_allMatch() {
        let score = PositionSimilarity.compute(
            predicted: ["A", "B", "C"],
            expected:  ["A", "B", "C"]
        )
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_position_noMatch() {
        let score = PositionSimilarity.compute(
            predicted: ["A", "B", "C"],
            expected:  ["D", "E", "F"]
        )
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    func test_position_partialMatch() {
        // Only position 0 matches (A == A), positions 1 and 2 differ
        let score = PositionSimilarity.compute(
            predicted: ["A", "C", "B"],
            expected:  ["A", "B", "C"]
        )
        XCTAssertEqual(score, 1.0 / 3.0, accuracy: 0.001)
    }

    func test_position_bothEmpty() {
        XCTAssertEqual(PositionSimilarity.compute(predicted: [], expected: []), 0.0)
    }

    // MARK: - MeanReciprocalRank

    func test_mrr_firstItemAlwaysCorrect() {
        // Each result list has the relevant item first → MRR = 1.0
        let results = [["topic1", "topic2"], ["topic1", "topic3"]]
        let mrr = MeanReciprocalRank.compute(results: results, relevant: ["topic1"])
        XCTAssertEqual(mrr, 1.0, accuracy: 0.001)
    }

    func test_mrr_secondItemCorrect() {
        // Relevant item always at position 2 (rank 2) → 1/2 = 0.5
        let results = [["topic2", "topic1"], ["topic3", "topic1"]]
        let mrr = MeanReciprocalRank.compute(results: results, relevant: ["topic1"])
        XCTAssertEqual(mrr, 0.5, accuracy: 0.001)
    }

    func test_mrr_neverFound() {
        let results = [["topic2", "topic3"], ["topic4", "topic5"]]
        let mrr = MeanReciprocalRank.compute(results: results, relevant: ["topic1"])
        XCTAssertEqual(mrr, 0.0, accuracy: 0.001)
    }

    func test_mrr_mixed() {
        // Query 1: relevant at rank 1 → 1.0, Query 2: relevant at rank 2 → 0.5
        // MRR = (1.0 + 0.5) / 2 = 0.75
        let results = [["topic1", "topic2"], ["topic2", "topic1"]]
        let mrr = MeanReciprocalRank.compute(results: results, relevant: ["topic1"])
        XCTAssertEqual(mrr, 0.75, accuracy: 0.001)
    }

    // MARK: - BLEUScore

    func test_bleu_identical() {
        let score = BLEUScore.compute(
            candidate: "the cat sat on the mat",
            references: ["the cat sat on the mat"]
        )
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_bleu_emptyCandidateReturnsZero() {
        let score = BLEUScore.compute(candidate: "", references: ["the cat sat"])
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    func test_bleu_partialMatch_greaterThanZero() {
        // Candidate shares some ngrams with reference but is not identical
        let score = BLEUScore.compute(
            candidate: "the cat sat",
            references: ["the cat sat on the mat"],
            maxNGram: 2
        )
        // Should be > 0 and < 1
        XCTAssertGreaterThan(score, 0.0)
        XCTAssertLessThan(score, 1.0)
    }

    func test_bleu_noOverlapReturnsZero() {
        let score = BLEUScore.compute(
            candidate: "hello world",
            references: ["the cat sat on the mat"],
            maxNGram: 1
        )
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    // MARK: - ROUGEScore

    func test_rouge_identical() {
        let output = ROUGEScore.compute(
            candidate: "the cat sat on the mat",
            reference: "the cat sat on the mat"
        )
        XCTAssertEqual(output.rouge1, 1.0, accuracy: 0.001)
        XCTAssertEqual(output.rouge2, 1.0, accuracy: 0.001)
        XCTAssertEqual(output.rougeL, 1.0, accuracy: 0.001)
    }

    func test_rouge_emptyReferenceReturnsZero() {
        let output = ROUGEScore.compute(candidate: "hello", reference: "")
        XCTAssertEqual(output.rouge1, 0.0)
        XCTAssertEqual(output.rouge2, 0.0)
        XCTAssertEqual(output.rougeL, 0.0)
    }

    func test_rouge_partialOverlap() {
        // candidate: "the cat sat", reference: "the cat sat on the mat"
        // ROUGE-1 recall: "the","cat","sat" all in reference (3/6 ref unigrams)... 
        // Actually recall = |overlap| / |reference| = 3/6 = 0.5 (ignoring "on","the","mat" duplication)
        let output = ROUGEScore.compute(
            candidate: "the cat sat",
            reference: "the cat sat on the mat"
        )
        XCTAssertGreaterThan(output.rouge1, 0.0)
        XCTAssertLessThan(output.rouge1, 1.0)
        XCTAssertGreaterThan(output.rougeL, 0.0)
        XCTAssertLessThanOrEqual(output.rougeL, 1.0)
    }

    func test_rouge_noOverlap() {
        let output = ROUGEScore.compute(candidate: "hello world", reference: "the cat sat")
        XCTAssertEqual(output.rouge1, 0.0, accuracy: 0.001)
        XCTAssertEqual(output.rouge2, 0.0, accuracy: 0.001)
    }
}
