## EvalKit Context

EvalKit is an open-source Swift Package Manager library for evaluating on-device AI 
models on iOS. Everything runs on-device — no data leaves the device.

### Five targets and what they cover
- EvalKit: core protocols, shared models, LatencyMeasurer, P90Calculator
- EvalKitClassification: accuracy, F1, precision, recall, confusion matrix, FP/FN rates
- EvalKitRetrieval: Jaccard, position similarity, MRR, BLEU, ROUGE
- EvalKitRules: deterministic rule-based output validation
- EvalKitJudge: LLM as a judge, binary/holistic/item-by-item scoring

### The four evaluation primitives
1. Classification — predicted == expected is the pass criterion
2. Retrieval — output is a ranked or unordered set compared to a reference
3. Rules — output is validated deterministically with code, no LLM needed
4. Judge — output quality requires language understanding to assess

### Primary audience
iOS developers building on-device AI features with CoreML and Apple FoundationModels.
Many have limited AI evaluation experience. Documentation must be educational first,
technical second. Never assume the reader knows what F1, Jaccard, BLEU, or MRR means.

### Real use cases
- Text classification (CoreML) → EvalKitClassification
- Topic finder / RAG → EvalKitRetrieval  
- Packing list generation → EvalKitRules + EvalKitJudge
- Personalised greeting generation → EvalKitRules + EvalKitJudge
- Any free-form text generation → EvalKitJudge

### Documentation standard
When writing docs for any EvalKit type, always explain:
1. What problem it solves
2. When to use it vs the alternative
3. A complete usage example showing real wiring, not just method calls