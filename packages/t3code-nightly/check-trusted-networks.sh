# Asserts that `t3` refuses plain-http links outside T3CODE_TRUSTED_NETWORKS
# and accepts them inside, through the real CLI. Port 9 is one fetch refuses,
# so an accepted URL fails at the probe instead, without network access.
# Usage: assertTrustedNetworks <t3 executable>
assertTrustedNetworks() {
  local t3=$1 home url trusted out
  home=$(mktemp -d)
  mkdir -p "$home/t3/userdata"
  echo '{"linkedEnvironmentsEnabled":true}' > "$home/t3/userdata/settings.json"

  # "-" stands for an empty list.
  linkOutput() {
    T3CODE_TRUSTED_NETWORKS=${1#-} HOME=$home T3CODE_HOME=$home/t3 \
      timeout 60 "$t3" environment link "$2" --pairing-code check 2>&1 | tail -n 5 || true
  }

  while read -r trusted url; do
    out=$(linkOutput "$trusted" "$url")
    if [[ $out != *"is plain http"* ]]; then
      printf 'ERROR: %s was not refused with T3CODE_TRUSTED_NETWORKS=%s:\n%s\n' "$url" "$trusted" "$out" >&2
      return 1
    fi
  done <<'EOF'
- http://ceres.t3.invalid:9
ceres.t3.invalid http://vesta.t3.invalid:9
ceres.t3.invalid http://sub.ceres.t3.invalid:9
ceres.t3.invalid http://ceres.t3.invalid.:9
192.0.2.0/25 http://192.0.2.200:9
EOF

  while read -r trusted url; do
    out=$(linkOutput "$trusted" "$url")
    if [[ $out != *"did not answer"* ]]; then
      printf 'ERROR: %s was refused with T3CODE_TRUSTED_NETWORKS=%s:\n%s\n' "$url" "$trusted" "$out" >&2
      return 1
    fi
  done <<'EOF'
ceres.t3.invalid http://ceres.t3.invalid:9
vesta.t3.invalid,ceres.t3.invalid http://CERES.T3.Invalid:9
192.0.2.0/24,ceres.t3.invalid http://192.0.2.10:9
2001:db8::/32 http://[2001:db8::10]:9
EOF

  rm -rf "$home"
}
