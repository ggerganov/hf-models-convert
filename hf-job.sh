#!/bin/bash
set -euo pipefail

# Hugging Face Job to run convert.sh on HF infrastructure
# Usage: ./hf-job.sh

echo ">>> Starting HF Job: Model Convert & Quantize"

hf jobs run \
    --flavor cpu-xl \
    --secrets HF_TOKEN \
    --env HF_HUB_ENABLE_HF_XET=1 \
    python:3.11-slim \
    bash -c '
    set -euo pipefail

    # Install system dependencies
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      cmake \
      && rm -rf /var/lib/apt/lists/*

    # Clone the conversion scripts
    git clone https://github.com/ggerganov/hf-models-convert.git /tmp/convert
    cd /tmp/convert

    # Run the conversion script
    bash convert.sh
'

echo ">>> Job submitted. Check logs with: hf jobs logs"
