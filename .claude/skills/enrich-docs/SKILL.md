---
name: enrich-docs
description: Enrich inline documentation for EvalKit Swift files. Use when the user wants to improve, complete, or audit doc comments across any target (e.g. "document FalseRateCalculator", "enrich docs for EvalKitRules", "add usage examples to reporters").
argument-hint: target-or-file
allowed-tools: Read, Edit, Bash
---

## Project context

!`cat CLAUDE.md`

## Files in target

!`find Sources/$argument -name "*.swift" | sort`

## Instructions

The user wants to enrich documentation for **$argument** (a target folder or specific file).

Read every Swift file in the target. For each public type, property, and method apply
the documentation standard below. Do not change any implementation logic — only doc comments.

---

## Documentation standard

### For every public TYPE (struct, enum, protocol, class)

Add or rewrite the doc comment with ALL of these sections in order:

**1. What is this?** — one sentence, plain English. Never start with the type name.
- Bad:  "JudgeReport is a struct that..."
- Good: "The final output of a complete LLM judge evaluation run."

**2. Why does it exist?** — what problem does it solve that nothing else in EvalKit solves?
Which primitive does it belong to (Classification / Retrieval / Rules / Judge)?

**3. When to use it** — bullet list of specific trigger conditions referencing real use cases:
- Text classification with CoreML
- Topic finder / RAG retrieval
- Packing list generation
- Personalised greeting generation
- Claim summarisation

**4. When NOT to use it** — name the specific alternative.
- "If your model predicts fixed labels, use StandardClassificationReporter instead."
- "If the check can be done with code, use RulesReporter instead of LLMJudgeReporter."

**5. Complete usage example** — a full ```swift block showing:
- Creating at least one test case
- Creating the runner or reporter with realistic parameters
- Getting the report or result
- Reading at least one meaningful metric
- Comments explaining each step

### For every public PROPERTY

Answer ALL of these:
- What does this value represent in plain English?
- For numeric metrics: what does 1.0 (high) mean? What does 0.0 (low) mean?
- For optionals: when is it nil? What does non-nil mean?
- For Bool: what makes it true? What action should the developer take?
- For collections: what does each element represent? What does empty mean?
- Which other property should this be compared against?

Example of expected quality:
/// Macro-averaged F1 score across all classes.
///
/// F1 is the harmonic mean of precision and recall. Use this when your
/// dataset is imbalanced — some labels appear far more often than others.
/// Unlike accuracy, F1 punishes a model that ignores rare classes.
///
/// - 1.0 = perfect precision and recall across all classes
/// - 0.0 = model never predicted any class correctly
/// - Use `macroF1` when all classes matter equally regardless of frequency
/// - Use `weightedF1` when frequent classes should carry more weight
///
/// Example: evaluating a flight disruption classifier with rare "cancel" events.
/// macroF1 = 0.72 means even rare classes are evaluated fairly.
/// High accuracy but low macroF1 means the model ignores rare classes.
///
/// `nil` for non-classification features.

### For every public METHOD

Answer ALL of these:
- Why would I call this? What is the goal?
- What do the parameters mean in plain English?
- What does the return value mean?
- What does it return on empty or invalid input?
- What is a common mistake developers make with this?

Use `/// - Parameter name:` and `/// - Returns:` format.
Add `/// - Note:` for common mistakes or important caveats.

---

## Tone rules — apply to every doc comment

1. Plain English first, formula second, real example with numbers third
2. Write for an iOS developer who has never done AI evaluation
3. Every numeric metric needs a concrete example — not "high is good" but what 0.75 means for a packing list
4. Never write a comment that only restates the method signature
5. Never write "see README for details" — every comment must be self-contained
6. Every reporter doc comment must mention: "Use `report.passedBaseline` as an XCTest assertion or CI pipeline gate."

---

## Metric definitions — use these consistently

- **Accuracy**: out of all predictions, how many were correct?
- **Precision**: out of all times the model predicted a label, how many were right?
- **Recall**: out of all actual instances of a label, how many did the model find?
- **F1**: balances precision and recall; use when classes are imbalanced
- **Macro average**: all classes weighted equally regardless of frequency
- **Weighted average**: classes weighted by how often they appear in the dataset
- **False Positive Rate**: how often does the model raise a false alarm?
- **False Negative Rate**: how often does the model miss a real problem?
- **Jaccard**: set overlap as fraction of union; order-independent
- **Position similarity**: how many elements match at the same rank?
- **MRR**: on average, how far down the list is the first correct answer?
- **BLEU**: n-gram overlap; use for translation or tasks where exact wording matters
- **ROUGE**: recall-oriented overlap; use for summarisation
- **P90**: 90% of cases scored at or below this; measures worst-case tail performance
- **Binary judge**: YES/NO grammar check; 1.0 = passed, 0.0 = failed
- **Holistic judge**: 1–5 impression score for subjective quality
- **Item-by-item judge**: ratio of facts found; e.g. 3/4 = 0.75

---

## Self-check before marking done

Before finishing, verify for every file processed:

- [ ] Every public type has: what is this, why it exists, when to use, when NOT to use, usage example
- [ ] Every numeric metric property has: plain English meaning, high value meaning, low value meaning, real example with numbers
- [ ] Every optional explains when it is nil
- [ ] Every reporter mentions `passedBaseline` as XCTest / CI gate
- [ ] No doc comment says "see README"
- [ ] No implementation logic was changed
- [ ] `swift build` passes after changes

## Output format

For each file processed, report:

**[FileName.swift]**
- Types updated: list each type and what was added
- Flagged for review: anything uncertain about purpose or usage