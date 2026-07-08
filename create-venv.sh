#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">>> Creating virtual environment"
python3 -m venv "$SCRIPT_DIR/venv"

echo ">>> Installing requirements"
. "$SCRIPT_DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ">>> Done. Activate with: source $SCRIPT_DIR/venv/bin/activate"
