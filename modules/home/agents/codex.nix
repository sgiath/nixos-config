{
  config,
  pkgs,
  lib,
  ...
}:
let
  codexExe = lib.getExe pkgs.llm-agents.codex;
  gitExe = lib.getExe pkgs.git;
  pythonExe = lib.getExe pkgs.python3;
  statExe = lib.getExe' pkgs.coreutils "stat";
  timeoutExe = lib.getExe' pkgs.coreutils "timeout";

  # Exit 0 when the requested cleanup action ("plugin" or "marketplace") should
  # run for the given CODEX_HOME. Fails closed on malformed config files,
  # conflicting or unrelated devfast snapshots, and profile-scoped devfast usage.
  codexCleanupCheckPy = ''
    import json, os, subprocess, sys, tomllib

    GIT_EXE = ${builtins.toJSON gitExe}
    WHITEBOARD_SOURCES = (
        "https://github.com/devdotfast/whiteboard.git",
        "https://github.com/devdotfast/whiteboard",
    )

    def is_whiteboard_source(entry):
        return (
            isinstance(entry, dict)
            and entry.get("source_type") in (None, "git")
            and entry.get("source") in WHITEBOARD_SOURCES
        )

    def load_toml(path):
        with open(path, "rb") as f:
            data = tomllib.load(f)
        if not isinstance(data, dict):
            sys.exit(1)
        return data

    def git_origin_is_whiteboard(git_cfg):
        # Reject git configs that delegate or rewrite remotes through includes,
        # insteadOf rules, or worktreeConfig so we never accept an indirect URL.
        indirect = subprocess.run(
            [
                GIT_EXE,
                "config",
                "--file",
                git_cfg,
                "--no-includes",
                "--null",
                "--get-regexp",
                r"^(include(if\..*)?\.path|url\..*\.(insteadof|pushinsteadof)|extensions\.worktreeconfig)$",
            ],
            capture_output=True,
            text=True,
        )
        if indirect.returncode != 1:
            return False

        res = subprocess.run(
            [GIT_EXE, "config", "--file", git_cfg, "--no-includes", "--null", "--get-all", "remote.origin.url"],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0:
            urls = [u for u in res.stdout.split("\0") if u]
            return bool(urls) and all(u in WHITEBOARD_SOURCES for u in urls)
        if res.returncode != 1:
            return False

        res = subprocess.run(
            [GIT_EXE, "config", "--file", git_cfg, "--no-includes", "--null", "--get-regexp", r"^remote\..*\.url$"],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            return False
        urls = []
        for entry in res.stdout.split("\0"):
            if not entry:
                continue
            parts = entry.split("\n", 1)
            if len(parts) != 2:
                return False
            urls.append(parts[1])
        return bool(urls) and all(u in WHITEBOARD_SOURCES for u in urls)

    def snapshot_identity(snap_dir):
        try:
            st = os.lstat(snap_dir)
        except OSError:
            return None
        return f"{st.st_dev}:{st.st_ino}"

    def retry_marker_matches(codex_dir, snap_dir):
        marker = retry_marker_path(codex_dir)
        if not os.path.isfile(marker):
            return False
        ident = snapshot_identity(snap_dir)
        if ident is None:
            return False
        try:
            with open(marker, "r", encoding="utf-8") as f:
                recorded = f.read().strip()
        except OSError:
            return False
        return recorded == ident

    def snapshot_verdict(codex_dir):
        """Return 'absent', 'whiteboard', 'other', or 'unknown' for .tmp/marketplaces/devfast."""
        snap_dir = os.path.join(codex_dir, ".tmp", "marketplaces", "devfast")
        if not os.path.exists(snap_dir) and not os.path.islink(snap_dir):
            return "absent"
        if os.path.islink(snap_dir) or not os.path.isdir(snap_dir):
            return "other"
        meta_path = os.path.join(snap_dir, ".codex-marketplace-install.json")
        git_entry = os.path.join(snap_dir, ".git")
        verified = False
        if os.path.exists(meta_path) or os.path.islink(meta_path):
            if os.path.islink(meta_path) or not os.path.isfile(meta_path):
                return "other"
            try:
                with open(meta_path, "r", encoding="utf-8") as f:
                    meta = json.load(f)
            except (OSError, ValueError):
                return "other"
            if not is_whiteboard_source(meta):
                return "other"
            verified = True
        if os.path.exists(git_entry) or os.path.islink(git_entry):
            # Reject .git pointer files, symlinks, worktree/common-dir layouts,
            # or an unverified .git directory alongside intact install metadata.
            if os.path.islink(git_entry) or not os.path.isdir(git_entry):
                return "other"
            for extra in ("config.worktree", "commondir"):
                p = os.path.join(git_entry, extra)
                if os.path.exists(p) or os.path.islink(p):
                    return "other"
            git_cfg = os.path.join(git_entry, "config")
            if os.path.exists(git_cfg) or os.path.islink(git_cfg):
                if os.path.islink(git_cfg) or not os.path.isfile(git_cfg):
                    return "other"
                if not git_origin_is_whiteboard(git_cfg):
                    return "other"
                verified = True
            elif verified:
                # Intact Whiteboard metadata with a missing .git/config is
                # protected unless our inode-bound retry marker matches a prior
                # interrupted removal.
                return "unknown"
        return "whiteboard" if verified else "unknown"

    def retry_marker_path(codex_dir):
        return os.path.join(codex_dir, ".tmp", ".whiteboard-devfast-removing")

    def is_whiteboard_devfast(codex_dir, cfg, allow_retry_marker=False):
        marketplaces = cfg.get("marketplaces")
        if marketplaces is not None and not isinstance(marketplaces, dict):
            sys.exit(1)
        devfast = marketplaces.get("devfast") if isinstance(marketplaces, dict) else None
        snap_dir = os.path.join(codex_dir, ".tmp", "marketplaces", "devfast")
        verdict = snapshot_verdict(codex_dir)
        if devfast is not None:
            if not is_whiteboard_source(devfast):
                return False
            # If a snapshot exists on disk, its metadata/origin must agree with
            # Whiteboard (never delete an unrelated or unverified checkout).
            return verdict in ("absent", "whiteboard")
        if verdict == "whiteboard":
            return True
        if allow_retry_marker and verdict == "unknown" and retry_marker_matches(codex_dir, snap_dir):
            return True
        return False

    def plugins_has_devfast(plugins, ignore_whiteboard=False):
        if plugins is None:
            return False
        if not isinstance(plugins, dict):
            sys.exit(1)
        for key in plugins:
            if not isinstance(key, str):
                sys.exit(1)
            if key.endswith("@devfast") and not (ignore_whiteboard and key == "whiteboard@devfast"):
                return True
        return False

    def plugins_has_key(plugins, target):
        if plugins is None:
            return False
        if not isinstance(plugins, dict):
            sys.exit(1)
        return target in plugins

    def marketplaces_has_devfast(marketplaces):
        if marketplaces is None:
            return False
        if not isinstance(marketplaces, dict):
            sys.exit(1)
        return "devfast" in marketplaces

    def config_has_devfast_plugins(data, ignore_top_whiteboard=False):
        if plugins_has_devfast(data.get("plugins"), ignore_whiteboard=ignore_top_whiteboard):
            return True
        profiles = data.get("profiles")
        if profiles is None:
            return False
        if not isinstance(profiles, dict):
            sys.exit(1)
        for prof in profiles.values():
            if not isinstance(prof, dict):
                sys.exit(1)
            if plugins_has_devfast(prof.get("plugins"), ignore_whiteboard=False):
                return True
        return False

    def config_has_profile_marketplace(data, include_top_level=False):
        if include_top_level and marketplaces_has_devfast(data.get("marketplaces")):
            return True
        profiles = data.get("profiles")
        if profiles is None:
            return False
        if not isinstance(profiles, dict):
            sys.exit(1)
        for prof in profiles.values():
            if not isinstance(prof, dict):
                sys.exit(1)
            if marketplaces_has_devfast(prof.get("marketplaces")):
                return True
        return False

    def config_has_profile_plugin(data, target, include_top_level=False):
        if include_top_level and plugins_has_key(data.get("plugins"), target):
            return True
        profiles = data.get("profiles")
        if profiles is None:
            return False
        if not isinstance(profiles, dict):
            sys.exit(1)
        for prof in profiles.values():
            if not isinstance(prof, dict):
                sys.exit(1)
            if plugins_has_key(prof.get("plugins"), target):
                return True
        return False

    def profile_config_files(codex_dir):
        try:
            entries = list(os.scandir(codex_dir))
        except OSError:
            sys.exit(1)
        return [entry.path for entry in entries if entry.name.endswith(".config.toml")]

    def has_profile_whiteboard(codex_dir, cfg):
        if config_has_profile_plugin(cfg, "whiteboard@devfast", include_top_level=False):
            return True
        for path in profile_config_files(codex_dir):
            if config_has_profile_plugin(
                load_toml(path), "whiteboard@devfast", include_top_level=True
            ):
                return True
        return False

    def has_profile_devfast_marketplace(codex_dir, cfg):
        if config_has_profile_marketplace(cfg, include_top_level=False):
            return True
        for path in profile_config_files(codex_dir):
            if config_has_profile_marketplace(load_toml(path), include_top_level=True):
                return True
        return False

    def has_other_devfast_plugins(codex_dir, cfg, ignore_top_whiteboard=False):
        if config_has_devfast_plugins(cfg, ignore_top_whiteboard=ignore_top_whiteboard):
            return True
        for path in profile_config_files(codex_dir):
            if config_has_devfast_plugins(load_toml(path), ignore_top_whiteboard=False):
                return True
        cache_dir = os.path.join(codex_dir, "plugins", "cache", "devfast")
        if os.path.isdir(cache_dir):
            try:
                cached = list(os.scandir(cache_dir))
            except OSError:
                sys.exit(1)
            for entry in cached:
                if entry.name != "whiteboard":
                    return True
        return False

    action = sys.argv[1]
    codex_dir = sys.argv[2]
    ignore_top_whiteboard = "--ignore-whiteboard" in sys.argv[3:]
    cfg_path = os.path.join(codex_dir, "config.toml")

    if action == "plugin":
        if not os.path.isfile(cfg_path):
            sys.exit(1)
        cfg = load_toml(cfg_path)
        plugins = cfg.get("plugins")
        has_wb = isinstance(plugins, dict) and "whiteboard@devfast" in plugins
        if not has_wb or not is_whiteboard_devfast(codex_dir, cfg, allow_retry_marker=False):
            sys.exit(1)
        if has_profile_whiteboard(codex_dir, cfg):
            sys.exit(1)
        sys.exit(0)

    if action == "marketplace":
        cfg = load_toml(cfg_path) if os.path.isfile(cfg_path) else {}
        if has_profile_devfast_marketplace(codex_dir, cfg):
            sys.exit(1)
        if not is_whiteboard_devfast(codex_dir, cfg, allow_retry_marker=True):
            sys.exit(1)
        if has_other_devfast_plugins(codex_dir, cfg, ignore_top_whiteboard=ignore_top_whiteboard):
            sys.exit(1)
        sys.exit(0)

    sys.exit(2)
  '';
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = [
        pkgs.llm-agents.codex
      ];
      file.".codex/AGENTS.md".source = ./AGENTS.md;
    };

    # Uninstall the previously Nix-installed whiteboard@devfast plugin and its
    # devfast marketplace when no other @devfast plugin remains in CODEX_HOME.
    home.activation.codexPluginCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      codex_dir="$HOME/.codex"
      if [[ -d $codex_dir ]]; then
        codex_exe=${lib.escapeShellArg codexExe}
        python_exe=${lib.escapeShellArg pythonExe}
        stat_exe=${lib.escapeShellArg statExe}
        timeout_exe=${lib.escapeShellArg timeoutExe}
        check_py=${lib.escapeShellArg codexCleanupCheckPy}
        retry_marker="$codex_dir/.tmp/.whiteboard-devfast-removing"
        snap_dir="$codex_dir/.tmp/marketplaces/devfast"

        dry_removed_wb=0
        if "$python_exe" -I -c "$check_py" plugin "$codex_dir" 2>/dev/null; then
          if [[ -v DRY_RUN ]]; then
            echo "Would remove Codex plugin whiteboard@devfast"
            dry_removed_wb=1
          else
            if out=$(CODEX_HOME="$codex_dir" "$timeout_exe" 60 "$codex_exe" plugin remove whiteboard@devfast </dev/null 2>&1); then
              echo "Codex: removed plugin whiteboard@devfast"
            else
              echo "Codex: removing plugin whiteboard@devfast failed; activation continues:" >&2
              echo "$out" >&2
            fi
          fi
        fi

        mkt_args=(marketplace "$codex_dir")
        if ((dry_removed_wb)); then
          mkt_args+=(--ignore-whiteboard)
        fi
        if "$python_exe" -I -c "$check_py" "''${mkt_args[@]}" 2>/dev/null; then
          if [[ -v DRY_RUN ]]; then
            echo "Would remove Codex plugin marketplace devfast"
          else
            if [[ -d $snap_dir && ! -L $snap_dir ]]; then
              if ! (mkdir -p "$codex_dir/.tmp" && "$stat_exe" -c '%d:%i' "$snap_dir" >"$retry_marker") 2>/dev/null; then
                echo "Codex: warning: could not record marketplace removal marker $retry_marker" >&2
              fi
            fi
            if out=$(CODEX_HOME="$codex_dir" "$timeout_exe" 60 "$codex_exe" plugin marketplace remove devfast </dev/null 2>&1); then
              rm -f "$retry_marker"
              echo "Codex: removed plugin marketplace devfast"
            else
              echo "Codex: removing plugin marketplace devfast failed; activation continues:" >&2
              echo "$out" >&2
            fi
          fi
        elif [[ ! -v DRY_RUN && -f $retry_marker ]]; then
          recorded=$(cat "$retry_marker" 2>/dev/null || true)
          current=""
          if [[ -d $snap_dir && ! -L $snap_dir ]]; then
            current=$("$stat_exe" -c '%d:%i' "$snap_dir" 2>/dev/null || true)
          fi
          if [[ -z $current || $current != "$recorded" ]]; then
            rm -f "$retry_marker"
          fi
        fi
      fi
    '';
  };
}
