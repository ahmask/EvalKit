// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeScoringPattern.swift
// EvalKitJudge/Models
//
// Describes the two fundamental scoring mechanisms used by a judge dimension.

import Foundation

/// Describes the fundamental scoring mechanism used by a judge dimension.
///
/// There are three distinct patterns, each requiring different prompt shapes,
/// different judge output formats, and different score aggregation logic.
/// They must NOT be collapsed into one implementation.
///
/// **Pattern 1 — Binary (YES/NO)**
///
/// Used for: fluency, language validity.
/// The judge answers a simple YES/NO question.
/// Score = 1.0 if passed, 0.0 if not.
/// JSON response shape: `{"passed": true|false, "reasoning": "<string>"}`
///
/// **Pattern 2 — Holistic (1–5 scale)**
///
/// Used for: tone, safety, coherence.
/// The judge reads input + output and gives one impression score with reasoning.
/// JSON response shape: `{"score": <1-5>, "reasoning": "<string>"}`
///
/// **Pattern 3 — Item-by-item (0 or 1 per fact)**
///
/// Used for: groundedness, recall.
/// The judge receives a list of specific facts and checks each one individually.
/// Score is a ratio: `sum(1s) / total facts`. E.g. 3/4 facts found = 0.75.
/// JSON response shape: `{"results": [{"fact": "<text>", "score": 0|1, "reasoning": "<string>"}]}`
public enum JudgeScoringPattern: Sendable {

    /// Judge answers a YES/NO question. Score = 1.0 if passed, 0.0 if not.
    /// Use for fluency and language validity — binary is more reliable than
    /// holistic scoring for grammatical correctness because it eliminates
    /// subjective impression and self-evaluation bias.
    case binary

    /// Judge reads input + output and returns a single score 1–5 with reasoning.
    ///
    /// Used for dimensions like tone, safety, and coherence where
    /// the evaluator forms one overall impression.
    case holistic

    /// Judge receives input + output + a list of key facts and scores each fact 0 or 1.
    ///
    /// Final score is a ratio: `sum(scores) / count(facts)`, mapped to `[0, 1]`
    /// for unified reporting. Raw per-fact results are preserved in `JudgeScore.factScores`.
    ///
    /// Used for dimensions like recall and groundedness where specific information
    /// must be verified fact-by-fact.
    ///
    /// - Parameter keyFacts: The default set of key facts to check. Individual
    ///   evaluation calls may override this list via `keyFactsOverride` in `LLMJudgeRunner`.
    case itemByItem(keyFacts: [String])
}
