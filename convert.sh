#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_SRC="Qwen/Qwen3.5-0.8B"
MODEL_DST="ggerganov/testing"
QUANT_TYPE="Q8_0"

cd "$SCRIPT_DIR"

# Check for HF_TOKEN
if [ -z "${HF_TOKEN:-}" ]; then
  echo "Error: HF_TOKEN environment variable is not set"
  exit 1
fi

# Get current SHA of the source model using HF API
echo ">>> Checking for updates in $MODEL_SRC"
CURRENT_SHA=$(python3 -c "import urllib.request, json, sys; print(json.load(urllib.request.urlopen('https://huggingface.co/api/models/' + sys.argv[1]))['sha'])" "$MODEL_SRC")

if [ -z "$CURRENT_SHA" ]; then
  echo "Error: Failed to retrieve model info from Hugging Face"
  exit 1
fi

# Fetch LAST_SHA from destination repo
echo ">>> Checking last processed SHA in $MODEL_DST"
LAST_SHA=$(curl -s "https://huggingface.co/$MODEL_DST/resolve/main/.src_sha")

if [ "$CURRENT_SHA" = "$LAST_SHA" ]; then
  echo ">>> Source model has not changed (SHA: $CURRENT_SHA). Skipping conversion."
  exit 0
fi

# Install HF CLI
echo ">>> Installing HF CLI"
pip install -r requirements.txt

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

# Re-install HF CLI (llama.cpp deps may have uninstalled it)
echo ">>> Re-installing HF CLI"
pip install -r requirements.txt

# ── Step 5: Create destination repo & upload ────────────────────────────────
hf repos create "$MODEL_DST" --type model --exist-ok --token "$HF_TOKEN"

# Store source SHA in destination repo
echo "$CURRENT_SHA" > "./model-quantized/.src_sha"

# Upload README.md, Q8_0 GGUF file, and source SHA
hf upload "$MODEL_DST" ./model-quantized \
  --include "*.gguf" --include ".src_sha" --include "README.md" \
  --type model \
  --token "$HF_TOKEN"

echo ">>> Done! Model uploaded to https://huggingface.co/$MODEL_DST"
