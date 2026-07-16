#!/bin/bash
set -euo pipefail

# Hugging Face Job to run convert.sh on HF infrastructure
# Usage: ./hf-job.sh --owner <owner> [--one <name>] [--filter <regex>] [--timeout <seconds>]

echo ">>> Starting HF Job: Model Convert & Quantize"

# Collect arguments to pass to convert.sh
OWNER=""
TIMEOUT="1h"
CONVERT_ARGS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --one)
            CONVERT_ARGS="$CONVERT_ARGS --one $2"
            shift 2
            ;;
        --filter)
            CONVERT_ARGS="$CONVERT_ARGS --filter $2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *}
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -z "$OWNER" ]; then
    echo "Error: --owner is required"
    exit 1
fi

hf jobs run \
    --namespace "$OWNER" \
    --timeout "$TIMEOUT" \
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
    git clone https://github.com/ggml-org/convert.git /tmp/convert
    cd /tmp/convert

    # Run the conversion script
    bash convert.sh --owner '"$OWNER"' '"$CONVERT_ARGS"'
'

echo ">>> Job submitted. Check logs with: hf jobs logs"
