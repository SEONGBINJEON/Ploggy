# Plogging Mobile Hand-off
- Primary model: `plogging_224_fp16.tflite` (float32 input, FP16 weights)
- Fallback: `plogging_224_dynamic.tflite`
- Input: [1,224,224,3] float32 RGB, 0..255
- Output: [1,6] logits/softmax; see `labels.txt`
- Disposal mapping: `disposal_map.json`
