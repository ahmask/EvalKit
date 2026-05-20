---
name: add-judge-dimension
description: Scaffold a new JudgeDimension static factory method in EvalKitJudge. Use when the user wants to add a new judge quality dimension (e.g. "add a conciseness dimension", "new judge dimension for empathy").
argument-hint: dimension-name
allowed-tools: Read, Edit, Bash
---

## Existing dimensions (for reference)

!`grep -n "public static func" Sources/EvalKitJudge/Models/JudgeDimension.swift`

## Scoring patterns available

- `.binary` — YES/NO factual question. JSON: `{"passed": true or false, "reasoning": "<string>"}`
- `.holistic` — subjective impression, 1–5 scale. JSON: `{"score": <1-5>, "reasoning": "<string>"}`
- `.itemByItem(keyFacts: [])` — 0/1 per fact, ratio score. JSON: `{"results": [{"fact": "<text>", "score": 0 or 1, "reasoning": "<string>"}]}`

## Instructions

The user wants to add a new judge dimension called **$argument**.

1. Choose the right scoring pattern:
   - Binary: use when the question has a factual yes/no answer (e.g. grammatical correctness)
   - Holistic: use when quality is genuinely subjective and a matter of degree (e.g. tone, safety)
   - Item-by-item: use when there is a list of discrete facts to check (e.g. recall, groundedness)

2. Write the prompt template following the exact style in JudgeDimension.swift:
   - Open with "You are a <role> evaluator..."
   - State what to check with bullet points
   - Include `{input}` and `{output}` placeholders
   - End with: `You must respond with ONLY a raw JSON object, no markdown, no backticks, no extra text:`
   - Then the exact JSON shape for the chosen pattern

3. Add the static factory method to `Sources/EvalKitJudge/Models/JudgeDimension.swift`:
   - Place it after the last built-in factory method, before `custom()`
   - Follow the doc comment style: one-line summary, scoring choice rationale, score meanings, `passed` condition
   - Include the file header comment `// EvalKit — all processing is on-device. No data leaves the device.` (already present — do not duplicate)

4. Add the new preset name to the dimension table in the doc comment block at the top of `JudgeDimension.swift` (the `| Factory | What it checks | Scoring |` table).

5. Update `CLAUDE.md` — add the new preset to the `Built-in JudgeDimension presets:` line in the Scoring patterns section.

6. Update `README.md` — add a new `### DimensionName (pattern)` section under "LLM as a Judge — what each metric measures", following the same structure as the existing sections.

7. Run `swift build` to confirm no compile errors before reporting done.
