# Prompt: Enrich EvalKit Documentation

Use the `evalkit-documentation` skill.

Go through every public type, property, and method in [TARGET FILE OR FOLDER].
For each one, apply the documentation structure defined in the skill exactly.

Rules:
- Do not change any implementation logic
- Do not skip any type because it seems simple or obvious
- The simplest-looking types often have the worst documentation gaps
- If a type is already used internally by another type, still document it
  as if an external developer might use it directly
- If a metric is already mentioned in the README, the inline doc comment 
  must still be self-contained — do not say "see README for details"

After enriching, for each file output:
- File name
- List of types updated
- Any type where you were uncertain about the purpose 
  (flag these so the developer can review)