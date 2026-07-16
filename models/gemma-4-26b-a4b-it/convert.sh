#!/bin/bash
set -euox pipefail

OUTPUT_DIR="$1"
LLAMA_CPP="$2"

DISPLAY_NAME="gemma-4-26B-A4B-it"
QUANTIZE="$LLAMA_CPP/build/bin/llama-quantize"

# --- Conversions ---

# Main model (no MTP layers)
python3 "$LLAMA_CPP/convert_hf_to_gguf.py" "$PATH_PRIMARY" \
    --outtype bf16 --outfile "$OUTPUT_DIR/${DISPLAY_NAME}-BF16.gguf" --model-name "$DISPLAY_NAME"

# MTP layers (from assistant repo)
python3 "$LLAMA_CPP/convert_hf_to_gguf.py" "$PATH_ASSISTANT" \
    --outtype bf16 --outfile "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-BF16.gguf" --model-name "$DISPLAY_NAME"

# --- Quantizations ---

# Main model: Q8_0
"$QUANTIZE" "$OUTPUT_DIR/${DISPLAY_NAME}-BF16.gguf" "$OUTPUT_DIR/${DISPLAY_NAME}-Q8_0.gguf" Q8_0 1>&2

# MTP: Q8_0
"$QUANTIZE" "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-BF16.gguf" "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-Q8_0.gguf" Q8_0 1>&2

# MTP Q4_0 from QAT
python3 "$LLAMA_CPP/convert_hf_to_gguf.py" "$PATH_QAT_Q4_0" \
    --outtype bf16 --outfile "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-QAT-BF16.gguf" --model-name "$DISPLAY_NAME"
"$QUANTIZE" --pure "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-QAT-BF16.gguf" "$OUTPUT_DIR/mtp-${DISPLAY_NAME}-Q4_0.gguf" Q4_0 1>&2

# Unquantized Q4_0 from QAT
python3 "$LLAMA_CPP/convert_hf_to_gguf.py" "$PATH_QAT_Q4_0_UNQUANTIZED" \
    --outtype bf16 --outfile "$OUTPUT_DIR/${DISPLAY_NAME}-QAT-BF16.gguf" --model-name "$DISPLAY_NAME"
"$QUANTIZE" --pure --tensor-type "^token_embd=q8_0" "$OUTPUT_DIR/${DISPLAY_NAME}-QAT-BF16.gguf" "$OUTPUT_DIR/${DISPLAY_NAME}-Q4_0.gguf" Q4_0 1>&2

# --- Produced files ---

echo "${DISPLAY_NAME}-BF16.gguf" >> "$OUTPUT_DIR/.produced_files"
echo "${DISPLAY_NAME}-Q8_0.gguf" >> "$OUTPUT_DIR/.produced_files"
echo "mtp-${DISPLAY_NAME}-BF16.gguf" >> "$OUTPUT_DIR/.produced_files"
echo "mtp-${DISPLAY_NAME}-Q8_0.gguf" >> "$OUTPUT_DIR/.produced_files"
echo "mtp-${DISPLAY_NAME}-Q4_0.gguf" >> "$OUTPUT_DIR/.produced_files"
echo "${DISPLAY_NAME}-Q4_0.gguf" >> "$OUTPUT_DIR/.produced_files"
