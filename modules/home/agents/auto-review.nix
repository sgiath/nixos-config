{
  config,
  lib,
  pkgs,
  apiKeyWrapper,
  namespace,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.services.auto-review;
  package = pkgs.${namespace}.auto-review;

  reviewer = types.submodule {
    options = {
      provider = mkOption {
        type = types.str;
        description = "T3 provider instance id.";
      };
      model = mkOption { type = types.str; };
      effort = mkOption { type = types.str; };
    };
  };

  names = mkOption {
    type = types.listOf types.str;
    default = [ ];
  };

  repo = types.submodule {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      checkout = mkOption {
        type = types.str;
        description = "Local clone the review reads git objects from.";
      };
      t3Project = mkOption {
        type = types.str;
        description = "T3 project id the review threads start in.";
      };
      context = mkOption {
        type = types.lines;
        default = "";
        description = "Repo-specific review instructions inserted into the brief.";
      };
      threshold = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Per-repo posting threshold; null uses the global one.";
      };
      requestChangesThreshold = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Per-repo request-changes threshold; null uses the global one.";
      };
      reviewer = mkOption {
        type = types.nullOr reviewer;
        default = null;
      };
      approval = mkOption {
        type = types.enum [
          "never"
          "when_clean"
        ];
        default = "when_clean";
        description = "Approve as you, pinned to the reviewed head, when the review finds nothing to post.";
      };
      rules = {
        reviewRequested = mkOption {
          type = types.bool;
          default = true;
          description = "Review MRs that request your review.";
        };
        includeAuthors = names;
        excludeAuthors = names;
        requireLabels = names;
        excludeLabels = names;
        skipDrafts = mkOption {
          type = types.bool;
          default = true;
        };
        waitForPipeline = mkOption {
          type = types.bool;
          default = true;
        };
      };
    };
  };

  repoJson = r: {
    inherit (r)
      enabled
      checkout
      context
      threshold
      reviewer
      approval
      ;
    t3_project = r.t3Project;
    request_changes_threshold = r.requestChangesThreshold;
    rules = {
      review_requested = r.rules.reviewRequested;
      include_authors = r.rules.includeAuthors;
      exclude_authors = r.rules.excludeAuthors;
      require_labels = r.rules.requireLabels;
      exclude_labels = r.rules.excludeLabels;
      skip_drafts = r.rules.skipDrafts;
      wait_for_pipeline = r.rules.waitForPipeline;
    };
  };

  # Defaults only: what the UI changes lives in $XDG_STATE_HOME/auto-review/overrides.json and wins.
  defaults = pkgs.writeText "auto-review-defaults.json" (
    builtins.toJSON {
      dry_run = cfg.dryRun;
      poll_interval_seconds = cfg.pollIntervalSeconds;
      inherit (cfg) threshold reviewer timezone;
      request_changes_threshold = cfg.requestChangesThreshold;
      auto_settle = cfg.autoSettle;
      note_template = cfg.noteTemplate;
      max_concurrent = cfg.maxConcurrent;
      max_launches_per_day = cfg.maxLaunchesPerDay;
      review_timeout_minutes = cfg.reviewTimeoutMinutes;
      quiet_hours = {
        enabled = cfg.quietHours.enable;
        inherit (cfg.quietHours) start end;
      };
      notify = {
        inherit (cfg.notify) desktop;
        ntfy_url = cfg.notify.ntfyUrl;
      };
      repos = lib.mapAttrs (_: repoJson) cfg.repos;
    }
  );
in
{
  options.services.auto-review = {
    enable = lib.mkEnableOption "review of the MRs and PRs that request your review, with a local web UI";

    port = mkOption {
      type = types.port;
      default = 8787;
      description = "Port of the web UI on 127.0.0.1.";
    };

    dryRun = mkOption {
      type = types.bool;
      default = false;
      description = "Review, but never write to GitLab or GitHub.";
    };
    pollIntervalSeconds = mkOption {
      type = types.ints.between 15 3600;
      default = 60;
    };
    threshold = mkOption {
      type = types.ints.positive;
      default = 5;
      description = "Minimum frequency × severity that gets posted.";
    };
    requestChangesThreshold = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Minimum frequency × severity of a posted or already open finding that sets the GitLab review state to requested changes instead of left comments.";
    };
    autoSettle = mkOption {
      type = types.bool;
      default = true;
      description = "Settle the T3 thread once its comments are posted, or when nothing is posted.";
    };
    noteTemplate = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Note on top of every posted comment; null uses the built-in one.";
    };
    reviewer = mkOption {
      type = reviewer;
      default = {
        provider = "opencode";
        # Remote repos override it with cliproxy/remote/claude-opus-5-5.
        model = "cliproxy/claude-opus-5-5";
        effort = "high";
      };
    };
    maxConcurrent = mkOption {
      type = types.ints.positive;
      default = 3;
    };
    maxLaunchesPerDay = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
    };
    reviewTimeoutMinutes = mkOption {
      type = types.ints.positive;
      default = 120;
      description = "Active running time (time stopped by a usage limit excluded) before a review fails.";
    };
    timezone = mkOption {
      type = types.str;
      default = "Europe/Prague";
      description = "Local time for quiet hours and the daily launch cap.";
    };
    quietHours = {
      enable = lib.mkEnableOption "quiet hours (no launches or posts)";
      start = mkOption {
        type = types.str;
        default = "22:00";
      };
      end = mkOption {
        type = types.str;
        default = "07:00";
      };
    };
    notify = {
      desktop = mkOption {
        type = types.bool;
        default = true;
      };
      ntfyUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "ntfy topic URL for failures, e.g. https://ntfy.sgiath.dev/auto-review.";
      };
    };
    repos = mkOption {
      type = types.attrsOf repo;
      default = { };
      description = "Watched repos by id: `gitlab:<project path>` or `github:<owner>/<repo>`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    systemd.user.services.auto-review = {
      Unit = {
        Description = "Review MRs and PRs that request my review (UI on 127.0.0.1:${toString cfg.port})";
        After = [
          "network-online.target"
          "t3code.service"
        ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        # with-api-keys supplies GH_TOKEN for gh; glab and t3 use their own logins.
        ExecStart = "${lib.getExe apiKeyWrapper} ${lib.getExe package} serve --defaults ${defaults} --port ${toString cfg.port}";
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
          "PYTHONUNBUFFERED=1"
        ];
        StateDirectory = "auto-review";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
        TimeoutStopSec = 30;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
