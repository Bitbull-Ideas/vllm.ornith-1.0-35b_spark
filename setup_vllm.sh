#!/usr/bin/env bash
# setup_vllm.sh — vLLM + Hugging Face setup on DGX Spark (GB10, Grace Blackwell ARM64)
# Run as a normal user. No root required after /srv/vllm2 is writable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
MODEL_DIR="${SCRIPT_DIR}/models"

echo "=== vLLM Setup for DGX Spark ==="
echo "Target: ${SCRIPT_DIR}"

if ! command -v uv &>/dev/null; then
    echo "[1/5] Installing uv ..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    # shellcheck disable=SC1091
    source "$HOME/.bashrc" 2>/dev/null || true
else
    echo "[1/5] uv already installed: $(uv --version)"
fi

echo "[2/5] Creating Python venv with uv ..."
uv venv "${VENV_DIR}" --python 3.12

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "[3/5] Installing Hugging Face tooling ..."
uv pip install huggingface-hub

echo "[4/5] Installing vLLM ..."
uv pip install vllm --torch-backend=auto

# vllm-gguf-plugin is intentionally not installed. It globally monkey-patches
# vLLM and breaks the FP8 safetensors path for this deployment.
if python - <<'PY'
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec('vllm_gguf_plugin') else 1)
PY
then
    echo "Removing vllm-gguf-plugin; this FP8 deployment must not load it."
    uv pip uninstall -y vllm-gguf-plugin || true
fi

echo "[5/5] Creating model directory: ${MODEL_DIR}"
mkdir -p "${MODEL_DIR}"

echo ""
echo "=== Setup complete ==="
echo "  Venv:   source ${VENV_DIR}/bin/activate"
echo "  Models: ${MODEL_DIR}/"
echo ""
echo "Next:"
echo "  bash ${SCRIPT_DIR}/download_model.sh"
echo "  bash ${SCRIPT_DIR}/vllm-server.sh"