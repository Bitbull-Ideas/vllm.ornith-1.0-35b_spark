#!/usr/bin/env bash
# download_model.sh — Download Ornith-1.0-35B FP8 via huggingface_hub
# Run from the same directory as setup_vllm.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/.venv/bin/activate"

MODEL_DIR="${SCRIPT_DIR}/models"
MODEL_REPO="${MODEL_REPO:-deepreinforce-ai/Ornith-1.0-35B-FP8}"
MODEL_NAME="${MODEL_NAME:-Ornith-1.0-35B-FP8}"
TARGET_DIR="${MODEL_DIR}/${MODEL_NAME}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/hf-cache}"

mkdir -p "${MODEL_DIR}" "${CACHE_DIR}"

echo "=== Model Download ==="
echo "  Repo:   ${MODEL_REPO}"
echo "  Format: FP8 safetensors / compressed-tensors"
echo "  Target: ${TARGET_DIR}"
echo "  Size:   ~36 GB"
echo ""

if [ -s "${TARGET_DIR}/model.safetensors.index.json" ]; then
    echo "Model already exists: ${TARGET_DIR}"
    du -sh "${TARGET_DIR}"
else
    echo "Downloading ${MODEL_REPO} ..."
    python3 - <<PY
from huggingface_hub import snapshot_download

path = snapshot_download(
    repo_id='${MODEL_REPO}',
    local_dir='${TARGET_DIR}',
    cache_dir='${CACHE_DIR}',
    allow_patterns=[
        '*.safetensors', '*.json', '*.jinja', 'vocab.json', 'tokenizer*'
    ],
)
print(f'Downloaded to: {path}')
PY
    echo ""
    echo "Download complete:"
    du -sh "${TARGET_DIR}"
fi

echo ""
echo "=== Contents of ${TARGET_DIR} ==="
ls -lh "${TARGET_DIR}" | head -30

echo ""
echo "Done. Start the server with:"
echo "  bash ${SCRIPT_DIR}/vllm-server.sh"