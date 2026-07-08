#!/bin/bash
set -euo pipefail

WORK_DIR="/home/ggerganov/hf-models-convert"
MODEL_SRC="Qwen/Qwen3.5-0.8B"
MODEL_DST="ggerganov/testing"
QUANT_TYPE="Q8_0"

cd "$WORK_DIR"

# Check for HF_TOKEN
if [ -z "${HF_TOKEN:-}" ]; then
  echo "Error: HF_TOKEN environment variable is not set"
  echo "Usage: export HF_TOKEN=your_token && ./convert.sh"
  exit 1
fi

# ── Step 1: Clone the source model ──────────────────────────────────────────
echo ">>> Downloading model: $MODEL_SRC"
hf download "$MODEL_SRC" --local-dir ./model-original

# ── Step 2: Build llama.cpp ─────────────────────────────────────────────────
echo ">>> Preparing llama.cpp"
if [ -d "llama.cpp" ]; then
  echo ">>> llama.cpp already exists, pulling latest master"
  cd llama.cpp && git checkout master && git pull && cd ..
else
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
fi
echo ">>> Building llama-quantize"
cd llama.cpp
rm -rf build
mkdir -p build && cd build
cmake .. -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_UI=OFF
make -j$(nproc) llama-quantize
cd ../..

echo ">>> Installing llama.cpp Python dependencies"
pip install -r llama.cpp/requirements.txt

# Convert to GGUF (FP16 first)
echo ">>> Converting to GGUF (FP16)"
python3 llama.cpp/convert_hf_to_gguf.py \
  "./model-original" \
  --outfile "./model-original/model-f16.gguf" \
  --outtype f16

# Quantize to Q8_0
echo ">>> Quantizing to $QUANT_TYPE"
mkdir -p "./model-quantized"
llama.cpp/build/bin/llama-quantize \
  "./model-original/model-f16.gguf" \
  "./model-quantized/model-q8_0.gguf" \
  "$QUANT_TYPE"

# ── Step 4: Prepare upload folder ───────────────────────────────────────────
echo ">>> Preparing upload folder"

# Create minimal model card
cat > "./model-quantized/README.md" << MODELCARD
---
license: other
tags:
- gguf
- quantized
base_model:
- $MODEL_SRC
---

WIP

MODELCARD

# ── Step 5: Create destination repo & upload ────────────────────────────────
hf repo create "$MODEL_DST" --repo-type model --exist-ok --token "$HF_TOKEN"

# Upload README.md
hf upload "$MODEL_DST" ./model-quantized/README.md --repo-type model \
  --token "$HF_TOKEN"

# Upload Q8_0 GGUF file
hf upload "$MODEL_DST" ./model-quantized/*.gguf --repo-type model \
  --token "$HF_TOKEN"

echo ">>> Done! Model uploaded to https://huggingface.co/$MODEL_DST"
