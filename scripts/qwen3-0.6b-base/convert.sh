#!/bin/bash
set -euo pipefail

OUTPUT_DIR="$1"
LLAMA_CPP="$2"

DISPLAY_NAME="Qwen3-0.6B-Base"
QUANTIZE="$LLAMA_CPP/build/bin/llama-quantize"

python3 "$LLAMA_CPP/convert_hf_to_gguf.py" "$PATH_PRIMARY" \
    --outfile "$OUTPUT_DIR/${DISPLAY_NAME}-BF16.gguf" --outtype bf16

"$QUANTIZE" "$OUTPUT_DIR/${DISPLAY_NAME}-BF16.gguf" "$OUTPUT_DIR/${DISPLAY_NAME}-Q8_0.gguf" Q8_0 1>&2

echo "${DISPLAY_NAME}-BF16.gguf"
echo "${DISPLAY_NAME}-Q8_0.gguf"
