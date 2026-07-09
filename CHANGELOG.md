# Changelog

All notable changes to this project are documented in this file.

## [v1.0.0] - 2026-07-09

### Added

- Initial public release of the DGX Spark vLLM deployment for DeepReinforce Ornith-1.0-35B FP8.
- Documents the validated FP8 safetensors path and why GGUF/vllm-gguf-plugin was rejected for this model.
- Includes setup, model download, vLLM server startup, user systemd service, smoke tests, and tool-calling validation.
- Records the validated long-context runtime profile on port 8000 with 262k context and OpenAI-compatible API behavior.
- Repository transferred to the Bitbull-Ideas corporate GitHub space.
