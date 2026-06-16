# modules/nixos/server

## OVERVIEW

Home-server service modules gated by `sgiath.server.enable`, usually enabled from `systems/x86_64-linux/vesta/default.nix`.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Service registry | `default.nix` | Add imports and the root server option. |
| Global proxy/TLS | `nginx.nix` | ACME Cloudflare, QUIC, shared nginx tuning. |
| Large integrated service | `matrix.nix` | Secrets, TURN/LiveKit, vhosts, ordering. |
| Reverse proxy template | `nas.nix`, `sinai.nix`, `sgiath.nix` | Static/proxy patterns and rewrites. |
| Game/app services | `foundry.nix`, `minecraft.nix`, `factorio.nix` | Hardcoded ports/working dirs. |
| Observability/search | `monitoring.nix`, `search.nix` | Local bind/proxy and `/data` roots. |

## CONVENTIONS

- Root gate: `config.sgiath.server.enable`; most modules also check `config.services.<name>.enable`.
- Nginx vhosts generally use `onlySSL`, `enableACME`, `kTLS`, and proxy to localhost/internal addresses.
- ACME Cloudflare credentials live under `/data/secrets`; preserve exact file paths unless rotating the server layout.
- Service state/content commonly lives under `/data`; avoid moving paths casually.
- Capture side effects: firewall ports, `users.users.sgiath.extraGroups`, systemd ordering, bind addresses, and proxy websocket settings.

## ANTI-PATTERNS

- Do not add services that bypass the `sgiath.server.enable` gate.
- Do not duplicate global nginx/ACME defaults inside each service unless service-specific behavior needs it.
- Do not expose LAN-only services publicly without matching existing proxy/TLS patterns.
- Do not change hardcoded ports/IPs/working dirs without checking vhost and firewall references.
- Do not re-enable commented prototypes such as `openclaw` without explicit user intent.

## VALIDATION

```bash
nixfmt modules/nixos/server/<file>.nix
NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK" nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'vesta.local'
```
