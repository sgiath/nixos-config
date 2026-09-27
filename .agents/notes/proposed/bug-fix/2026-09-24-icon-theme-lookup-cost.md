# Agent Note: Quickshell icon theme lookups are slow

Status: proposed

## Problem

Found while fixing launcher lag on 2026-09-24. The launcher no longer draws icons, but notifications and the crash panel still resolve them via `Quickshell.iconPath(name, true)` / `image://icon/<name>` and `QIcon::fromTheme`. No Qt icon theme is configured (qt6ct has no `icon_theme`), so lookups fall back to `hicolor`. The GTK theme is Tela, but it does not configure Qt's theme lookup.

The `hicolor` directories under `~/.nix-profile/share/icons`, `/run/current-system/sw/share/icons`, and Quickshell's own `share/icons` lack `icon-theme.cache`; `~/.local/share/icons` has one. The original strace showed ~16k `access()` calls per uncached hicolor directory per lookup, ~80k for two lookups, and ~19 ms per lookup. Qt's `qtIconCache` is a `QCache` with default cost 100, so cycling through more than 100 names repeats the work.

Affected consumers include `modules/home/desktop/quickshell/notifications/Toast.qml` (up to two `iconPath` calls per toast) and `modules/home/desktop/quickshell/crash/CrashPanel.qml` through `launcher/AppIcon.qml`.

## Proposal

Make theme lookup efficient for the remaining Quickshell icon consumers. Candidate approaches are generating `icon-theme.cache` for the profile hicolor directories or configuring a Qt icon theme with a cache, such as the installed Tela theme.

## Acceptance criteria

- Notifications and crash-panel icons continue to resolve with their expected appearance.
- Repeated lookups across more than 100 distinct names avoid the observed ~19 ms per-lookup cost and large `access()` burst.

## Risks

Selecting a different Qt icon theme may alter icon appearance; generating caches in store-managed icon directories may require packaging changes rather than in-place writes.
