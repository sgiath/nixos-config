# Operations: lifecycle and diagnose

Read this file when the health check in SKILL.md indicates the daemon is missing, not running, or the extension isn't connected — or when the user explicitly asks to install, start, stop, restart, or troubleshoot kimi-webbridge.

## Local setup

This machine installs Kimi WebBridge declaratively from `/home/sgiath/nixos`:

- Package: `packages/kimi-webbridge/default.nix`
- User service: `homes/x86_64-linux/sgiath@ceres/default.nix`
- Service name: `kimi-webbridge.service`
- Binary should be on PATH as `kimi-webbridge`

Do not run the upstream installer, uninstaller, or upgrader by default. Changes should go through the NixOS repo and `nixos-rebuild switch --sudo --flake .`.

## Routing table (what to do based on status)

Run: `kimi-webbridge status`

| Observed                                               | Action                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `command not found` or binary missing                  | Repo/system not rebuilt yet. From `/home/sgiath/nixos`, run `nix build '.#kimi-webbridge'` to verify the package, then ask before running `nixos-rebuild switch --sudo --flake .` if a system switch is needed.                                                                               |
| `{"running": false, ...}`                              | Daemon not running. Run `systemctl --user start kimi-webbridge.service`, then re-check `kimi-webbridge status`.                                                                                                                                                                               |
| `{"running": true, "extension_connected": false, ...}` | Extension not connected. Tell the user: "If you've already installed the Kimi WebBridge extension, please open your browser and try again. If not yet installed, see https://www.kimi.com/features/webbridge (中文: https://www.kimi.com/zh-cn/features/webbridge) for install instructions." |
| `{"running": true, "extension_connected": true, ...}`  | Healthy. Return to the main SKILL.md to make tool calls.                                                                                                                                                                                                                                      |

## /status JSON fields

- `running` (bool) — daemon listening on `:10086`
- `port` (int) — 10086
- `version` (string) — daemon build version
- `extension_connected` (bool) — a WebSocket client is attached
- `extension_id` (string) — the Chrome/Edge extension ID, empty if none
- `uptime_seconds` (int)

## Daily operations

- **Check daemon status:** `kimi-webbridge status`
- **Check systemd status:** `systemctl --user status kimi-webbridge.service`
- **Start:** `systemctl --user start kimi-webbridge.service`
- **Stop:** `systemctl --user stop kimi-webbridge.service`
- **Restart after unexpected state:** `systemctl --user restart kimi-webbridge.service`
- **View service logs:** `journalctl --user -u kimi-webbridge.service -n 100`
- **Follow service logs:** `journalctl --user -u kimi-webbridge.service -f`
- **View app logs if needed:** `kimi-webbridge logs -n 100`

## Diagnosing common failures

| Symptom                                                          | Action                                                                                                                                                                                                                       |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Service fails with "address already in use"                      | `systemctl --user stop kimi-webbridge.service`, then check the conflicting process with `ss -ltnp 'sport = :10086'` or `lsof -i :10086` if available.                                                                        |
| Tool calls time out                                              | `journalctl --user -u kimi-webbridge.service -n 100` and `kimi-webbridge logs -n 100`; check for `[error]` / `panic` lines.                                                                                                  |
| `extension_connected` stays `false` after install                | Browser extension not running. If the user has it installed, ask them to open the browser and retry; otherwise direct them to https://www.kimi.com/features/webbridge (中文: https://www.kimi.com/zh-cn/features/webbridge). |
| `status` returns `extension_connected: true` but tool call fails | May be a multi-browser conflict. `kimi-webbridge logs -n 100` will show recent upgrade rejections.                                                                                                                           |
