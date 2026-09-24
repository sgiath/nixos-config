# Icon theme lookups cost ~20 ms each in Quickshell

Found while fixing launcher lag (2026-09-24). The launcher no longer draws
icons; other surfaces still pay this cost.

- `Quickshell.iconPath(name, true)` / `image://icon/<name>` go through
  `QIcon::fromTheme`. No Qt icon theme is configured (qt6ct has no
  `icon_theme`), so lookups fall back to `hicolor`.
- The `hicolor` dirs have no `icon-theme.cache`: `~/.nix-profile/share/icons`,
  `/run/current-system/sw/share/icons`, `~/.local/share/icons` (has one),
  and quickshell's own `share/icons`. strace: ~16k `access()` calls per
  hicolor dir per lookup, ~80k per two lookups, ~19 ms per lookup.
- Qt caches only the last 100 icon names (`qtIconCache`, a `QCache` with
  default cost 100), so a shell touching more than 100 names repeats these
  lookups continually.
- Still affected: `notifications/Toast.qml` (two `iconPath` calls per toast)
  and `crash/CrashPanel.qml` (`launcher/AppIcon.qml`).
- Possible fixes: generate `icon-theme.cache` for the profile hicolor dirs,
  or set a Qt icon theme that ships a cache (e.g. the installed Tela).
