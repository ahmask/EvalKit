---
name: sync-docs
description: Audit README.md and CLAUDE.md for inaccuracies relative to the current source code. Use when the user wants to check or fix documentation drift (e.g. "check the docs are accurate", "sync docs with source", "any doc inconsistencies?").
allowed-tools: Read, Bash
---

## Source of truth — JudgeDimension factory methods

!`grep -A 4 "public static func" Sources/EvalKitJudge/Models/JudgeDimension.swift`

## Source of truth — scoring patterns per factory

!`grep -E "(scoringPattern:|name:)" Sources/EvalKitJudge/Models/JudgeDimension.swift | grep -v "//" | head -40`

## Source of truth — EvaluationRule conformers

!`ls Sources/EvalKitRules/Rules/`

## Source of truth — Package targets

!`grep "\.target\|\.testTarget" Package.swift`

## Current README.md — LLM as a Judge section

!`awk '/## LLM as a Judge/,/## How scores are aggregated/' README.md`

## Current CLAUDE.md — Scoring patterns section

!`awk '/## Scoring patterns/,/## Adding a new target/' CLAUDE.md`

## Instructions

Compare the source output above against the README and CLAUDE.md sections.

Check specifically for:

1. **Scoring pattern mismatches** — does the documentation describe the correct pattern (binary/holistic/item-by-item) for each dimension? Cross-check each factory method's `scoringPattern:` argument against what README/CLAUDE.md say.

2. **Missing dimensions** — are all factory methods listed in both CLAUDE.md presets line and the README metrics section?

3. **JSON shape accuracy** — do documented JSON shapes match what the prompt templates actually ask the judge to return?

4. **Score scale accuracy** — if README mentions a 1–5 scale for a dimension, is that dimension actually `.holistic`? If it mentions YES/NO or pass/fail, is it actually `.binary`?

5. **Stale target list** — does CLAUDE.md's architecture section list the correct five targets from Package.swift?

Report each inconsistency as:
- **File**: README.md or CLAUDE.md
- **Section**: exact heading
- **Issue**: what the doc says vs what the source says
- **Fix needed**: the corrected text

Do not make any edits — report only. The user will decide which fixes to apply.
