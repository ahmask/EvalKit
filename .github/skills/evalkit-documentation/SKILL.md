# EvalKit Documentation Skill

Use this skill for any task that involves writing or enriching documentation 
across EvalKit source files.

## Structure for every public TYPE

### 1. What is this? (one sentence, plain English)
Example: "The final output of a complete judge evaluation run."
Never start with the type name: not "JudgeReport is a struct that..."

### 2. Why does it exist?
What problem does it solve that nothing else in EvalKit solves?
Which evaluation primitive does it belong to?

### 3. When to use it
Bullet list of specific trigger conditions referencing real use cases:
- greeting generation, packing list, topic finder, text classification

### 4. When NOT to use it
Name the specific alternative and when to reach for it instead.
Example: "If your model predicts fixed labels, use StandardClassificationReporter."

### 5. Complete usage example
A full ```swift block showing:
- Creating test cases
- Creating the runner or reporter  
- Getting the report
- Reading at least one meaningful metric

## Structure for every public PROPERTY

Answer all of these:
- What does this value represent in plain English?
- What does a high value mean? What does a low mean? (numeric metrics)
- When is it nil? (optionals)
- Which other property should I compare it against?

Example of expected quality:
/// Macro-averaged F1 score across all classes.
///
/// F1 is the harmonic mean of precision and recall. It is the right metric
/// when your dataset is imbalanced — some labels appear far more than others.
/// Unlike accuracy, F1 punishes a model that ignores rare classes.
///
/// - 1.0 = perfect precision and recall across all classes
/// - 0.0 = model never predicted any class correctly
/// - Use macroF1 when all classes matter equally regardless of frequency
/// - Use weightedF1 when frequent classes should carry more weight
///
/// `nil` for non-classification features.

## Structure for every public METHOD

Answer all of these:
- Why would I call this?
- What do the parameters mean in plain English, not just their type?
- What does the return value mean?
- What does it return on empty or invalid input?
- What is a common mistake developers make with this?

## Tone rules
- Plain English first, formula second, example with numbers third
- Write for an iOS developer who has never done AI evaluation
- Every numeric metric needs a real example: what does 0.75 mean in practice?
- Never write documentation that only restates the method signature