---
name: add-eval-rule
description: Scaffold a new EvaluationRule conformer in EvalKitRules. Use when the user wants to add a deterministic rule for validating model output (e.g. "add a rule for max characters", "new rule that checks no URLs in output").
argument-hint: rule-name
allowed-tools: Read, Edit, Bash
---

## Existing rules (for reference)

!`ls Sources/EvalKitRules/Rules/`

## EvaluationRule protocol

!`cat Sources/EvalKitRules/Protocols/EvaluationRule.swift`

## Instructions

The user wants to add a new rule called **$argument**.

Rules are deterministic — no LLM, no randomness. The same input always produces the same result.
Only add a rule if the check can be expressed as code. If it requires judgment, suggest a JudgeDimension instead.

1. Create `Sources/EvalKitRules/Rules/<RuleName>Rule.swift` following this structure:
   - File header: `// EvalKit — all processing is on-device. No data leaves the device.`
   - One `public struct` conforming to `EvaluationRule`
   - `public let name: String` — snake_case, e.g. `"max_characters"`
   - `public let failureMessage: String` — states what the rule requires
   - `public func evaluate(output: String, context: [String: String]) -> Bool`
   - If the failure description benefits from showing the actual observed value (e.g. actual character count vs limit), override `failureDescription(for:context:)` too
   - Any configurable limits/parameters are stored as `public let` properties set via `init`

2. Add a case to the `EvaluationRule` conformance table in the `EvaluationRule.swift` doc comment (the `| Checkable with code? | Use | Example |` table).

3. Add a test in `Tests/EvalKitRulesTests/RulesTests.swift`:
   - One test for the passing case
   - One test for the failing case
   - One test for edge cases (empty string, exact boundary value)

4. Run `swift test --filter EvalKitRulesTests` to confirm tests pass before reporting done.
