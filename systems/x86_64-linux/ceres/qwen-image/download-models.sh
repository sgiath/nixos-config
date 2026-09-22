#!/usr/bin/env bash
set -euo pipefail

models="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/comfyui/models}"
official_url="https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/ace0edeb3791a594ddfa36ed5f41a178a394e921"

fetch_model() {
  local base_url="$1" source="$2" target="$models/$3" checksum="$4"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]] && printf '%s  %s\n' "$checksum" "$target" | sha256sum --check --status; then
    printf 'Verified %s\n' "$target"
    return
  fi
  printf 'Downloading %s\n' "$source"
  curl --fail --location --retry 3 --continue-at - --output "$target.part" "$base_url/$source"
  printf '%s  %s\n' "$checksum" "$target.part" | sha256sum --check
  mv "$target.part" "$target"
}

fetch_model "$official_url" vae/qwen_image_2.1_vae_bf16.safetensors vae/qwen_image_2.1_vae_bf16.safetensors \
  bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9
fetch_model "$official_url" diffusion_models/qwen_image_2.1_int8_convrot.safetensors diffusion_models/qwen_image_2.1_int8_convrot.safetensors \
  cb74113cb03faecd79611b01fd7fd642f0aa60d6f0b95086abee214d75eaa57d
fetch_model "$official_url" text_encoders/qwen3vl_8b_int8_convrot.safetensors text_encoders/qwen3vl_8b_int8_convrot.safetensors \
  8bfd0f6e12abf2d2d697ecc888e5e90b0d6741d6708f05799f53afa560452e8f
# Prompt-enhancer (PE) Qwen3.5-9B text encoders used by ComfyUI-Qwen-Image-2.1-Prompt-Enhancer;
# same immutable HF revision, sha256 taken from the repo's LFS metadata.
fetch_model "$official_url" text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors \
  9182abae56fe05459840a86d22abd21f972061c92fce032630af680c8c5178d3
fetch_model "$official_url" text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors \
  32707d01b427e488af252b95c551989aad59f9fec611a694f5db6bde7f0f1f6c
printf 'Qwen-Image 2.1 models ready in %s\n' "$models"
