#!/bin/bash
set -euo pipefail

# Hugging Face Job to convert and quantize a model
# Usage: ./hf-job.sh

echo ">>> Starting HF Job: Model Convert & Quantize"

hf jobs run \
  --flavor cpu-performance \
  --secrets HF_TOKEN \
  --env HF_HUB_ENABLE_HF_XET=1 \
  python:3.11-slim \
  bash -c '
    set -euo pipefail

    apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      cmake \
      && rm -rf /var/lib/apt/lists/*

    # Clone the conversion scripts
    git clone https://github.com/ggerganov/hf-models-convert.git /tmp/convert
    cd /tmp/convert

    # Clone llama.cpp and build
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
    cd llama.cpp && mkdir build && cd build
    cmake .. -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_UI=OFF
    make -j$(nproc) llama-quantize
    cd ../..

    # Install llama.cpp Python dependencies
    pip install -r llama.cpp/requirements.txt

    # Download source model
    hf download Qwen/Qwen3.5-0.8B --local-dir ./model-original --token "$HF_TOKEN"

    # Convert to GGUF (FP16)
    python3 llama.cpp/convert_hf_to_gguf.py \
      ./model-original \
      --outfile ./model-original/model-f16.gguf \
      --outtype f16

    # Quantize to Q8_0
    mkdir -p ./model-quantized
    llama.cpp/build/bin/llama-quantize \
      ./model-original/model-f16.gguf \
      ./model-quantized/model-q8_0.gguf \
      Q8_0

    # Create model card
    cat > ./model-quantized/README.md << MODELCARD
---
license: other
tags:
- gguf
- quantized
base_model:
- Qwen/Qwen3.5-0.8B
---

WIP
MODELCARD

    # Create destination repo
    hf repos create ggerganov/testing --type model --exist-ok --token "$HF_TOKEN"

    # Upload results
    hf upload ggerganov/testing ./model-quantized/README.md --type model --token "$HF_TOKEN"
    hf upload ggerganov/testing ./model-quantized/*.gguf --type model --token "$HF_TOKEN"

    echo ">>> Done! Model uploaded to https://huggingface.co/ggerganov/testing"
  '

echo ">>> Job submitted. Check logs with: hf jobs logs"
