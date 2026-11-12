# Local LLM models (llama.cpp on Ceres)

This folder holds the GGUF models served by `llama-server` in router mode.
The service is defined in `~/nixos/modules/nixos/services/llama-cpp.nix`;
this README is linked here from `llama-cpp/models-README.md` next to it, so
edit it there, not here.

- Chat UI: <http://127.0.0.1:8081> (from other Nebula peers:
  <http://ceres.nebula.sgiath.dev:8081>)
- OpenAI-compatible API: `http://127.0.0.1:8081/v1`, model name = the file
  name without `.gguf` (or the subdirectory name, see below).
- One model is loaded at a time; asking for another unloads the current one.
  After 5 minutes idle the model is unloaded and its VRAM freed.

## Adding a model

1. Pick a GGUF repository on Hugging Face. Good sources: `unsloth/*-GGUF`,
   `bartowski/*-GGUF`, `ggml-org/*-GGUF`, or the vendor's own `*-GGUF` repo.
   Open "Files and versions" and choose a quantization:
   - `Q4_K_M` is the default choice.
   - `Q5_K_M` / `Q6_K` for higher quality when the file still fits.
   - Fit check: the RX 6950 XT has 16 GB, and the desktop already uses 4-5 GB.
     Keep the file below roughly 10 GB so the context (KV cache) also fits.
     8-9B models at Q4-Q6 and 14B at Q4 fit; 27B and larger do not fit fully
     on the GPU and run much slower.

2. Download it straight into this folder with curl. `-C -` resumes an
   interrupted download:

   ```sh
   cd /var/lib/llama-cpp-models
   curl -fL -C - -O https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf
   ```

   Use `resolve/main/...`, not `blob/main/...` (that is the HTML page).
   Gated repositories need a token: add
   `-H "Authorization: Bearer $HF_TOKEN"`.

3. Models that come as several files go into their own subdirectory, named
   as you want the model to appear:
   - Multi-shard (`*-00001-of-00003.gguf`, ...): all shards in one subdirectory.
   - Vision models: the model GGUF plus its projector in one subdirectory; the
     projector file name must start with `mmproj` (e.g. `mmproj-F16.gguf`).

4. Make the server pick it up (no restart needed):

   ```sh
   sudo systemctl reload llama-cpp
   curl -s http://127.0.0.1:8081/v1/models | jq -r '.data[].id'
   ```

## Per-model settings

A new model runs with safe defaults: 8k context, as many layers on the GPU as
fit (the rest on the CPU), and the GGUF's own chat template with tool calling
(`--jinja`).

To tune a model (longer context, all layers on the GPU, thinking off, a
different chat template), add a section for it to `modelsPreset` in
`~/nixos/modules/nixos/services/llama-cpp.nix`. The section name is the model
id from `/v1/models`, and its keys are `llama-server` flags without the
leading dashes. Then rebuild:

```sh
nixos-rebuild switch --sudo --flake ~/nixos#ceres
```

Models tuned for the agent evals use `evalProfile`: 32k context (16k for
`gpt-oss-20b-MXFP4`, which leaves too little VRAM at 32k), all layers
on the GPU (loading fails instead of falling back to the CPU), 8k default
output (`n-predict`; a request's `max_tokens` still overrides it), and a q8_0
KV cache. Add `noThinking` for models that can switch thinking off. A model
that does not fit with these settings fails to load (the request errors and
`journalctl -u llama-cpp` shows the allocation failure) instead of running
slowly on the CPU; lower its `ctx-size` in that case.

Chat templates: if a GGUF's embedded template does not produce `tool_calls`,
save the official `chat_template.jinja` in `templates/` here and add
`chat-template-file = /var/lib/llama-cpp-models/templates/<name>.jinja` to its
section.

## Permissions

The service runs as its own dynamic user, so every model file must be readable
by others (`-rw-r--r--`). The folder has a default ACL that makes this happen
for files created here (curl, wget, browser downloads saved here), even with
the 077 umask.

Files moved or copied in from elsewhere can stay private (`-rw-------`):
`mv` keeps the old mode, and `cp` (even with `--no-preserve=mode`) applies
the umask itself.
Fix them with:

```sh
chmod -R a+rX /var/lib/llama-cpp-models
ls -l /var/lib/llama-cpp-models
```

Symptom of a wrong mode: the model may still be listed in `/v1/models`, but
`journalctl -u llama-cpp` shows `failed to open GGUF file ... (Permission
denied)` and requests to it fail. After `chmod`, run
`sudo systemctl reload llama-cpp`.

## Removing a model

```sh
rm /var/lib/llama-cpp-models/<file>.gguf
sudo systemctl reload llama-cpp
```

## Troubleshooting

- Logs: `journalctl -u llama-cpp -f`
- Router settings: `curl -s http://127.0.0.1:8081/props | jq .`
- Whether a model is sleeping:
  `curl -s 'http://127.0.0.1:8081/props?model=<model-id>' | jq .is_sleeping`
- VRAM in use (bytes): `cat /sys/class/drm/card1/device/mem_info_vram_used`
- Right after a restart the server refuses connections for about a second
  while it starts.
- Do not use `systemctl restart` to pick up models; `reload` rescans the
  folder without dropping the server.
