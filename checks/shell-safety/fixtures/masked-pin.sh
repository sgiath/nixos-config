#!/usr/bin/env bash
# Rejected fixture: a failing command substitution passed as an argument does
# not stop the script, so npm installs with an empty version
# (t3code-nightly-device-tools pins).
set -euo pipefail

pin() {
  jq -er --arg name "$1" '.[$name] // empty' pins.json
}

npm install --package-lock-only "expo-device-hub@$(pin expo-device-hub)"
