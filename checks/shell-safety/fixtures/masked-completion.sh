#!/usr/bin/env bash
# Rejected fixture: process substitution hides the generator's exit status, so
# a completion generator that exits 42 still installs partial output and the
# script succeeds (t3code-nightly completions).
set -euo pipefail

out=$1

for shell in bash fish zsh; do
  installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
done
