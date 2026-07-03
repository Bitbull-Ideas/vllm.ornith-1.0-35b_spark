#!/usr/bin/env bash
# test_vllm.sh — vLLM server smoke test for model list and chat completion.
set -euo pipefail

HOST="${HOST:-localhost}"
PORT="${PORT:-8000}"
BASE_URL="http://${HOST}:${PORT}"
MODEL="${1:-Ornith-1.0-35B}"

echo "=== vLLM Test ==="
echo "Server: ${BASE_URL}"
echo "Model:  ${MODEL}"
echo ""

echo "--- GET /v1/models ---"
curl -fsS "${BASE_URL}/v1/models" | jq .

echo ""
echo "--- POST /v1/chat/completions ---"
curl -fsS "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${MODEL}"'",
    "messages": [
      {"role": "user", "content": "Reply with a short greeting."}
    ],
    "max_tokens": 128,
    "temperature": 0.0
  }' | jq '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, reasoning: .choices[0].message.reasoning}'

echo ""
echo "=== Done ==="