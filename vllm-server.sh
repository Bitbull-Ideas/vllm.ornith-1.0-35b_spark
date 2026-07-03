#!/usr/bin/env bash
# vllm-server.sh — OpenAI-compatible vLLM server for Ornith-1.0-35B FP8.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/.venv/bin/activate"

MODEL_REPO="${MODEL_REPO:-deepreinforce-ai/Ornith-1.0-35B-FP8}"
MODEL_PATH="${MODEL_PATH:-${SCRIPT_DIR}/models/Ornith-1.0-35B-FP8}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-Ornith-1.0-35B}"
TOKENIZER="${TOKENIZER:-${MODEL_PATH}}"

PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
GPU_MEM_UTIL="${GPU_MEM_UTIL:-0.5}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-3}"

if [ ! -s "${MODEL_PATH}/model.safetensors.index.json" ]; then
  echo "Model directory not found or incomplete: ${MODEL_PATH}"
  echo "Run: bash ${SCRIPT_DIR}/download_model.sh"
  exit 1
fi

echo "=== GPU Info ==="
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader 2>/dev/null || true
python - <<'PY' || true
try:
    import torch
    if torch.cuda.is_available():
        p = torch.cuda.get_device_properties(0)
        print(f"torch_gpu_total_gib={p.total_memory / (1024**3):.3f}")
except Exception as exc:
    print(f"torch_probe_error={exc!r}")
PY

echo "=== Starting vLLM Server ==="
echo "  Model repo:  ${MODEL_REPO}"
echo "  Model path:  ${MODEL_PATH}"
echo "  Served as:   ${SERVED_MODEL_NAME}"
echo "  Tokenizer:    ${TOKENIZER}"
echo "  Port:         ${HOST}:${PORT}"
echo "  Context:      ${MAX_MODEL_LEN}"
echo "  Batch toks:   ${MAX_NUM_BATCHED_TOKENS}"
echo "  Max seqs:     ${MAX_NUM_SEQS}"
echo "  GPU Mem:      ${GPU_MEM_UTIL} (0.5 ~= 60.8 GiB on 121.7 GiB GB10)"
echo "  Reasoning:    qwen3"
echo "  Tool parser:  qwen3_xml"
echo "  Mode:         text-only"
echo ""

ARGS=(
  "${MODEL_PATH}"
  "--served-model-name" "${SERVED_MODEL_NAME}"
  "--tokenizer" "${TOKENIZER}"
  "--host" "${HOST}"
  "--port" "${PORT}"
  "--max-model-len" "${MAX_MODEL_LEN}"
  "--max-num-batched-tokens" "${MAX_NUM_BATCHED_TOKENS}"
  "--max-num-seqs" "${MAX_NUM_SEQS}"
  "--gpu-memory-utilization" "${GPU_MEM_UTIL}"
  "--enable-prefix-caching"
  "--enable-auto-tool-choice"
  "--tool-call-parser" "qwen3_xml"
  "--reasoning-parser" "qwen3"
  "--trust-remote-code"
  "--enforce-eager"
  "--language-model-only"
)

echo "> vllm serve ${ARGS[*]}"
exec vllm serve "${ARGS[@]}"