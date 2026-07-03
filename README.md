# vLLM DGX Spark — Ornith-1.0-35B FP8

Optimized vLLM inference setup for **DGX Spark (GB10, Grace Blackwell ARM64)** with 128 GB unified memory, serving **DeepReinforce Ornith-1.0-35B** through an OpenAI-compatible API.

This repository documents the working DGX Spark deployment that was validated on a real host with user-level systemd, port `8000`, 262k context, OpenAI-compatible tool calls, and persistent autostart.

## Quickstart

```bash
sudo mkdir -p /srv/vllm2
sudo chown "$USER:$USER" /srv/vllm2
cd /srv/vllm2
git clone https://github.com/hermes-speedboat/vllm.ornith-1.0-35b_spark.git .

bash setup_vllm.sh
bash download_model.sh
bash vllm-server.sh
```

## Model and format

| Item | Value |
|---|---|
| Served model name | `Ornith-1.0-35B` |
| vLLM model path | `/srv/vllm2/models/Ornith-1.0-35B-FP8` |
| Hugging Face repo | `deepreinforce-ai/Ornith-1.0-35B-FP8` |
| Format | FP8 safetensors / compressed-tensors |
| Disk size | ~36 GB |
| Context | `262144` tokens |
| vLLM version validated | `0.24.0` |
| Port | `8000` |
| Text mode | `--language-model-only` |

## Why FP8 instead of GGUF

The original request started from `deepreinforce-ai/Ornith-1.0-35B-GGUF`, but the Hugging Face README uses different runtimes for different formats:

- the **vLLM** example targets the non-GGUF model family / vLLM-native format;
- the **GGUF** example targets `llama.cpp` / Ollama (`llama-server`), not vLLM.

The current `vllm-gguf-plugin` path was tested and rejected for this model. The plugin failed through multiple Qwen3.5-MoE incompatibilities and ultimately failed inside quantized fused-layer loading. The practical vLLM-native path is the official FP8 safetensors repo:

```text
deepreinforce-ai/Ornith-1.0-35B-FP8
```

Important: if you previously installed `vllm-gguf-plugin` while testing GGUF, uninstall it before running this FP8 service. It globally monkey-patches vLLM and can break safetensors startup with errors like:

```text
TypeError: GGUFConfig.override_quantization_method() got an unexpected keyword argument 'hf_config'
```

## Working runtime settings

The validated deployment uses:

```text
PORT=8000
HOST=0.0.0.0
MAX_MODEL_LEN=262144
MAX_NUM_BATCHED_TOKENS=8192
MAX_NUM_SEQS=3
GPU_MEM_UTIL=0.5
```

The generated vLLM command includes:

```bash
vllm serve /srv/vllm2/models/Ornith-1.0-35B-FP8 \
  --served-model-name Ornith-1.0-35B \
  --tokenizer /srv/vllm2/models/Ornith-1.0-35B-FP8 \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 262144 \
  --max-num-batched-tokens 8192 \
  --max-num-seqs 3 \
  --gpu-memory-utilization 0.5 \
  --enable-prefix-caching \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_xml \
  --reasoning-parser qwen3 \
  --trust-remote-code \
  --enforce-eager \
  --language-model-only
```

## Measured capacity on DGX Spark

Validated with `GPU_MEM_UTIL=0.5` and `MAX_NUM_SEQS=3`:

| Metric | Value |
|---|---:|
| Available KV cache memory | `24.02 GiB` |
| GPU KV cache size | `1,225,394 tokens` |
| Maximum concurrency at 262,144 tokens/request | `4.67x` |
| vLLM EngineCore process memory reported by `nvidia-smi` | `61542 MiB` |

Older comparison runs:

| GPU memory utilization | Available KV cache | Full-context concurrency |
|---:|---:|---:|
| `0.49` | `22.19 GiB` | `4.32x` |
| `0.60` | `35.66 GiB` | `6.94x` |

For approximately three long-running full-context sessions, `GPU_MEM_UTIL=0.5` with `MAX_NUM_SEQS=3` gives a useful safety margin.

## Files

| File | Purpose |
|---|---|
| `setup_vllm.sh` | Install uv, create `.venv`, install vLLM and Hugging Face tooling |
| `download_model.sh` | Download `deepreinforce-ai/Ornith-1.0-35B-FP8` with `snapshot_download()` |
| `vllm-server.sh` | Start the validated vLLM server |
| `vllm.service` | User systemd service for persistent operation |
| `test_vllm.sh` | Basic `/v1/models` and chat smoke test |
| `test_tools.sh` | OpenAI-compatible tool-call and tool-result round-trip test |

## Systemd autostart

### Prerequisites for headless user services

```bash
sudo apt install dbus dbus-user-session
sudo loginctl enable-linger "$USER"
echo 'export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"' >> ~/.bashrc
source ~/.bashrc
```

`loginctl enable-linger` is important: it lets the user systemd manager start and keep services without an active SSH login.

### Install service

```bash
mkdir -p ~/.config/systemd/user/
cp vllm.service ~/.config/systemd/user/
chmod +x /srv/vllm2/vllm-server.sh
systemctl --user daemon-reload
systemctl --user enable --now vllm.service
```

### Verify persistence

```bash
systemctl --user --no-pager status vllm.service
systemctl --user is-enabled vllm.service
loginctl show-user "$USER" -p Linger -p State
ss -tlnp | grep ':8000\b'
curl -fsS http://127.0.0.1:8000/v1/models | jq .
```

Expected:

```text
Active: active (running)
enabled
Linger=yes
LISTEN 0.0.0.0:8000
```

## API validation

```bash
bash test_vllm.sh
bash test_tools.sh
```

Expected `/v1/models` response includes:

```json
{
  "id": "Ornith-1.0-35B",
  "max_model_len": 262144
}
```

## Tool calling and MCP

This service was validated with OpenAI-style tools:

- `tools` payload accepted;
- `tool_choice: "auto"` can emit structured `tool_calls` when the prompt is direct and the token budget is sufficient;
- `tool_choice: "required"` emits structured `tool_calls` reliably;
- named tool choice works;
- tool-result round-trip works.

Example returned tool call:

```json
{
  "type": "function",
  "function": {
    "name": "get_weather",
    "arguments": "{\"location\": \"Zurich, Switzerland\"}"
  }
}
```

MCP is client-side orchestration: vLLM does not run MCP servers directly. MCP-capable clients such as Hermes expose MCP tools to the model as OpenAI-compatible `tools`, execute the selected tool, then feed the tool result back to the model. Since this endpoint supports OpenAI-style tool calls, it is suitable for MCP-backed tool use from such clients.

Caveat: for vague prompts with `tool_choice: "auto"` and too small `max_tokens`, the model may spend the response in the `reasoning` field and not reach the emitted tool call. Use enough completion budget, or force `tool_choice: "required"` / named tool choice when a tool must be called.

## Hermes configuration

Example OpenAI-compatible custom provider settings:

```bash
hermes config set model.base_url http://spark.example.com:8000/v1
hermes config set model.provider custom
hermes config set model.default Ornith-1.0-35B
```

Replace `spark.example.com` with your host or IP. Public examples intentionally use `example.com` instead of internal hostnames.

## Troubleshooting

### vLLM restarts hang

vLLM can hang during FastAPI/EngineCore shutdown. The service uses:

```ini
SendSIGKILL=yes
```

If a restart is stuck, clear it with:

```bash
systemctl --user kill --signal=SIGKILL vllm.service || true
systemctl --user reset-failed vllm.service || true
systemctl --user start vllm.service
```

### GGUF plugin breaks FP8 startup

If logs mention `vllm_gguf_plugin` while serving FP8, remove it:

```bash
/srv/vllm2/.venv/bin/python -m pip uninstall -y vllm-gguf-plugin
systemctl --user restart vllm.service
```

### OpenWebUI 404s

Routes such as `/api/tags`, `/api/v1/models`, `/props` may return 404 because they are Ollama-style routes. Configure clients to use the OpenAI-compatible endpoint:

```text
http://spark.example.com:8000/v1
```

### First request latency

The first request may trigger Triton JIT warnings and latency spikes. This is normal after a fresh start:

```text
Triton kernel JIT compilation during inference
```

Subsequent requests are faster once kernels are compiled.
