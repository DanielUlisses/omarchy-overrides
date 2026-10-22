#!/usr/bin/env bash

# Local AI: Ollama as a user service (the system unit needs root and keeps models in
# /var/lib) with a small model that fits the 4 GB RTX 500, and voxtype's meeting mode
# (mic + PipeWire monitor, no bot on the call) summarizing through that model.
# Configs are voxtype/ and ollama/, linked by bin/run-cmd-stow.sh; run that first.

set -euo pipefail

MODEL="qwen3:4b-instruct" # non-thinking Qwen3 4B, 2.5 GB: ~87% on the GPU
WHISPER="small"           # multilingual; language = "en,pt" in voxtype/.config/voxtype/config.toml

yay -S --noconfirm --needed ollama-cuda voxtype-bin

systemctl --user daemon-reload
systemctl --user enable --now ollama
for _ in $(seq 20); do curl -sf localhost:11434/api/version >/dev/null && break; sleep 1; done
ollama pull "$MODEL"

voxtype setup --download --model "$WHISPER" --no-post-install
systemctl --user restart voxtype
echo "Local AI ready: $MODEL for Ollama, $WHISPER for voxtype."
