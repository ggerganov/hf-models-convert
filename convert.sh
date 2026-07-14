#!/bin/bash
set -euox pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
ONE_MODEL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --one)
            ONE_MODEL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -z "${HF_TOKEN:-}" ]; then
    echo "Error: HF_TOKEN environment variable is not set"
    exit 1
fi

# Cross-platform CPU count
if command -v nproc &>/dev/null; then
    CPU_COUNT=$(nproc)
elif command -v sysctl &>/dev/null; then
    CPU_COUNT=$(sysctl -n hw.ncpu)
else
    CPU_COUNT=4
fi

echo ">>> Preparing llama.cpp"
if [ -d "llama.cpp" ]; then
    echo ">>> llama.cpp already exists, pulling latest master"
    cd llama.cpp && git checkout master && git pull && cd ..
else
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
fi

echo ">>> Building llama-quantize"
cd llama.cpp
mkdir -p build && cd build
cmake .. -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_UI=OFF
make -j"$CPU_COUNT" llama-quantize
cd ../..

echo ">>> Installing HF CLI"
pip install -r requirements.txt

# Build list of configs to process
if [ -n "$ONE_MODEL" ]; then
    config_paths=("scripts/${ONE_MODEL}/config.sh")
    if [ ! -f "${config_paths[0]}" ]; then
        echo "Error: No config.sh found for model '$ONE_MODEL'"
        exit 1
    fi
else
    config_paths=(scripts/*/config.sh)
fi

# Iterate over selected config(s)
for config_path in "${config_paths[@]}"; do
    script_dir="$(dirname "$config_path")"

    # Clean up DEP_* and PATH_* from previous iteration
    for var in $(compgen -v | grep -E '^(DEP_|PATH_)' || true); do
        unset "$var"
    done

    source "$config_path"

    display="${DISPLAY_NAME}"
    dest="${DEST_REPO}"
    upload_dir="./upload-${display//-/_}"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ">>> Processing: $display → $dest"
    echo "═══════════════════════════════════════════════════════════"

    # Collect all DEP_* variable keys (e.g. PRIMARY, DFLASH, EAGLE3)
    dep_keys=$(compgen -v | grep '^DEP_' | sed 's/^DEP_//' | sort)

    # Fetch current SHAs for all dependencies
    current_sha_lines=""
    for key in $dep_keys; do
        repo_var="DEP_$key"
        repo="${!repo_var}"

        echo ">>> Checking for updates in $repo ($key)"
        sha=$(python3 -c "import urllib.request, json, sys; print(json.load(urllib.request.urlopen('https://huggingface.co/api/models/' + sys.argv[1]))['sha'])" "$repo")

        if [ -z "$sha" ]; then
            echo "Error: Failed to retrieve model info from Hugging Face for $repo"
            exit 1
        fi

        current_sha_lines+="${key}=${sha}"$'\n'
    done

    # Read last-processed SHAs from destination repo
    last_sha_file=$(curl -Ls "https://huggingface.co/$dest/resolve/main/.src_sha" 2>/dev/null || echo "")

    # Compare — re-convert if ANY dependency changed
    needs_convert=false
    for key in $dep_keys; do
        current=$(echo "$current_sha_lines" | grep "^${key}=" | cut -d= -f2-)
        last=$(echo "$last_sha_file" | grep "^${key}=" | cut -d= -f2- 2>/dev/null || echo "")

        if [ "$current" != "$last" ]; then
            echo ">>> $key changed (current: ${current:0:8}…, last: ${last:0:8}…)"
            needs_convert=true
            break
        fi
    done

    if [ "$needs_convert" = false ]; then
        echo ">>> No dependency changes detected. Uploading README only."
        rm -rf "$upload_dir"
        mkdir -p "$upload_dir"
        cp "$script_dir/README.md" "$upload_dir/"
        hf repos create "$dest" --type model --exist-ok"
        hf upload "$dest" "$upload_dir" --include "README.md" --type model"
        rm -rf "$upload_dir"
        continue
    fi

    # Download all dependencies
    rm -rf "$upload_dir"
    mkdir -p "$upload_dir"
    cp "$script_dir/README.md" "$upload_dir/"

    temp_dirs=()
    for key in $dep_keys; do
        repo_var="DEP_$key"
        repo="${!repo_var}"
        temp_dir="./model-temp-${display//-/_}-${key}"
        temp_dirs+=("$temp_dir")

        echo ">>> Downloading $repo → $key"
        hf download "$repo" --local-dir "$temp_dir"

        export "PATH_$key=$temp_dir"
    done

    echo ">>> Running conversion script: $script_dir/convert.sh"
    bash "$script_dir/convert.sh" "$upload_dir" "./llama.cpp" 2>&1 | tee "$upload_dir/convert.log"
    produced_files=$(grep '\.gguf$' "$upload_dir/convert.log")

    # Write .src_sha with all dependency SHAs
    printf "%s" "$current_sha_lines" > "$upload_dir/.src_sha"

    hf repos create "$dest" --type model --exist-ok

    gguf_flags=""

    while IFS= read -r file; do
        [ -n "$file" ] && gguf_flags="$gguf_flags --include $file"
    done <<< "$produced_files"

    hf upload "$dest" "$upload_dir" \
        $gguf_flags --include ".src_sha" --include "README.md" --include "convert.log" \
        --type model

    echo ">>> Uploaded to https://huggingface.co/$dest"

    rm -rf "$upload_dir"
    for dir in "${temp_dirs[@]}"; do
        rm -rf "$dir"
    done
    for key in $dep_keys; do
        unset "PATH_$key"
    done
done

echo ""
echo ">>> All done!"
