#!/usr/bin/env bash

set -uo pipefail

readonly COREDUMP_MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1
readonly PROCESS_EXIT_MESSAGE_ID=98e322203f7a4ed290d09fe03c09fe15
readonly UNIT_FAILED_MESSAGE_ID=d9b373ed55a64feb8242e02dbe79a49c
# Transient units the Quickshell launcher starts apps in (launcher/Apps.qml).
readonly APP_UNIT_PREFIX=app-sgiath-
readonly dedupe_seconds=${SYSTEM_FAILURE_WATCHER_DEDUPE_SECONDS:-300}
readonly session=${SYSTEM_FAILURE_WATCHER_TMUX_SESSION:-nixos}
readonly working_directory=${SYSTEM_FAILURE_WATCHER_WORKING_DIRECTORY:-$HOME/nixos}
readonly herdr_bin=${SYSTEM_FAILURE_WATCHER_HERDR:-herdr}
readonly tmux_bin=${SYSTEM_FAILURE_WATCHER_TMUX:-tmux}
readonly omp_bin=${SYSTEM_FAILURE_WATCHER_OMP:-omp}
readonly journalctl_bin=${SYSTEM_FAILURE_WATCHER_JOURNALCTL:-journalctl}
readonly jq_bin=${SYSTEM_FAILURE_WATCHER_JQ:-jq}

declare -A last_dispatched
# app unit -> "<exit code> <exit status>"; systemd logs the main process
# exit right before the unit's failure verdict.
declare -A app_exit

log() {
  printf 'system-failure-watcher: %s\n' "$*" >&2
}

# Tab in the Herdr workspace checked out at the working directory, OMP
# started in it by Herdr so it shows up as a tracked agent. Returns 1 only
# when Herdr has no such workspace; once a tab exists it is the dispatch,
# even if the agent then fails to come up (the log says so).
dispatch_herdr() {
  local label=$1 prompt=$2 workspace pane reply

  # shellcheck disable=SC2016 # $path is jq's, bound with --arg
  workspace=$("$herdr_bin" workspace list 2>/dev/null | "$jq_bin" -r --arg path "$working_directory" '
    [.result.workspaces[]? | select((.worktree // {}).checkout_path == $path) | .workspace_id] | first // empty
  ') || return 1
  [[ -n $workspace ]] || return 1

  pane=$("$herdr_bin" tab create --workspace "$workspace" --cwd "$working_directory" \
    --label "$label" --no-focus 2>/dev/null | "$jq_bin" -r '.result.root_pane.pane_id // empty') || return 1
  [[ -n $pane ]] || return 1

  # Readiness detection needs an idle prompt first; a prompt on the command
  # line would put OMP straight to work and time the start out.
  if ! reply=$("$herdr_bin" agent start "$label" --kind omp --pane "$pane" 2>&1); then
    log "herdr tab $label opened but OMP did not start: $reply"
    return 0
  fi
  if ! reply=$("$herdr_bin" agent prompt "$label" "$prompt" 2>&1); then
    log "herdr tab $label opened but the prompt was not delivered: $reply"
  fi
}

dispatch_tmux() {
  local label=$1 prompt=$2

  "$tmux_bin" has-session -t "$session:" 2>/dev/null || return 1
  "$tmux_bin" new-window -d -t "$session:" -c "$working_directory" -n "$label" "$omp_bin" "$prompt"
}

dispatch() {
  local key=$1 label=$2 prompt=$3
  local now=${EPOCHSECONDS:-0}
  local last=${last_dispatched[$key]:-0}

  if ((now - last < dedupe_seconds)); then
    log "deduplicated $key"
    return 0
  fi

  label=${label//[^a-zA-Z0-9_.-]/-}
  label=failed-${label:0:40}-$now

  if dispatch_herdr "$label" "$prompt"; then
    last_dispatched[$key]=$now
    log "opened herdr tab $label for $key"
  elif dispatch_tmux "$label" "$prompt"; then
    last_dispatched[$key]=$now
    log "opened tmux window $label for $key"
  else
    log "neither herdr nor tmux session '$session' is available; skipped $key"
  fi
}

handle_coredump() {
  local entry=$1 uid comm pid exe signal unit name prompt

  IFS=$'\t' read -r uid comm pid exe signal unit < <(
    "$jq_bin" -r '
      def field: if . == null or . == "" then "-" else . end;
      [
        (._UID | field),
        (.COREDUMP_COMM | field),
        (.COREDUMP_PID | field),
        (.COREDUMP_EXE | field),
        (.COREDUMP_SIGNAL_NAME | field),
        ((.COREDUMP_USER_UNIT // .COREDUMP_UNIT) | field)
      ] | @tsv
    ' <<<"$entry" 2>/dev/null
  )

  [[ $uid =~ ^[0-9]+$ && $uid -eq $UID ]] || return 0
  [[ $pid =~ ^[0-9]+$ ]] || return 0

  # A failed service produces its own unit event. Let that event own the
  # diagnosis rather than opening a second window for the same failure.
  [[ $unit == *.service ]] && return 0

  name=$comm
  [[ $exe == /* ]] && name=${exe##*/}
  name=${name##*/}
  [[ -n $name && $name != "-" && $name != "." && $name != ".." ]] || name=unknown

  prompt="Investigate the application crash for '$name' on this host. The recorded PID is $pid, the executable is '$exe', and the signal is '$signal'. Start with 'coredumpctl info $pid' and inspect the matching journal entries and stack trace. Establish the root cause and fix it in this NixOS repository when the failure is configuration-owned. Do not merely suppress the crash or restart the application. If the fault is upstream, collect enough evidence for a useful upstream report."

  dispatch "crash:$exe" "$name" "$prompt"
}

# Remembers how a launcher app's main process ended so the failure verdict
# can tell a user's kill -9 from a crash.
handle_process_exit() {
  local entry=$1 unit uid code status

  IFS=$'\t' read -r unit uid code status < <(
    "$jq_bin" -r '
      def field: if . == null or . == "" then "-" else . end;
      [(.USER_UNIT | field), (._UID | field), (.EXIT_CODE | field), (.EXIT_STATUS | field)] | @tsv
    ' <<<"$entry" 2>/dev/null
  )

  [[ $unit == "$APP_UNIT_PREFIX"*.service && $uid =~ ^[0-9]+$ && $uid -eq $UID ]] || return 0
  app_exit[$unit]="$code $status"
}

handle_app_failure() {
  local unit=$1 result=$2 code status id prompt

  read -r code status <<<"${app_exit[$unit]:-- -}"
  unset "app_exit[$unit]"

  # SIGKILL is the user's doing (forcekillactive, kill -9); systemd already
  # counts TERM/INT/HUP/PIPE as clean exits, and an OOM kill carries its own
  # result so it still gets through.
  [[ $result == signal && $status == 9 ]] && return 0

  # app-sgiath-<desktop id>-<launch timestamp>.service
  id=${unit#"$APP_UNIT_PREFIX"}
  id=${id%-*}

  prompt="Investigate why the desktop application '$id' died after being launched from the shell launcher on this host. It ran as the transient user unit '$unit' and ended with result '$result' (main process $code, status $status). The unit is already collected; its output and systemd's verdict are in the journal: 'journalctl --user -u $unit --no-pager'. Find the '$id.desktop' entry through XDG_DATA_DIRS for the exact command line. Establish the root cause and fix it in this NixOS repository when the failure is configuration-owned (missing dependency, environment, wrapper, package option). Do not merely relaunch the application or suppress the error. If the fault is upstream, collect enough evidence for a useful upstream report."

  dispatch "app:$id" "$id" "$prompt"
}

handle_unit_failure() {
  local entry=$1 unit user_unit uid result scope prompt

  IFS=$'\t' read -r unit user_unit uid result < <(
    "$jq_bin" -r '
      def field: if . == null or . == "" then "-" else . end;
      [(.UNIT | field), (.USER_UNIT | field), (._UID | field), (.UNIT_RESULT | field)] | @tsv
    ' <<<"$entry" 2>/dev/null
  )

  if [[ $unit != "-" ]]; then
    scope=system
  elif [[ $user_unit != "-" && $uid =~ ^[0-9]+$ && $uid -eq $UID ]]; then
    scope=user
    unit=$user_unit
  else
    return 0
  fi

  [[ $unit == *.service ]] || return 0
  [[ $unit != system-failure-watcher.service ]] || return 0

  if [[ $scope == user && $unit == "$APP_UNIT_PREFIX"* ]]; then
    handle_app_failure "$unit" "$result"
    return
  fi

  if [[ $scope == user ]]; then
    prompt="Investigate the failed systemd user service '$unit' on this host. Start with 'systemctl --user status $unit' and 'journalctl --user -u $unit -b --no-pager'. Establish the root cause and fix it in this NixOS repository when the service is configuration-owned. Do not merely restart the service, reset its failed state, or suppress the error."
  else
    prompt="Investigate the failed systemd system service '$unit' on this host. Start with 'systemctl status $unit' and 'journalctl -u $unit -b --no-pager'. Establish the root cause and fix it in this NixOS repository when the service is configuration-owned. Do not merely restart the service, reset its failed state, or suppress the error."
  fi

  dispatch "service:$scope:$unit" "$unit" "$prompt"
}

consume() {
  local entry message_id

  while IFS= read -r entry; do
    message_id=$("$jq_bin" -r '.MESSAGE_ID // ""' <<<"$entry" 2>/dev/null) || continue

    case "$message_id" in
      "$COREDUMP_MESSAGE_ID") handle_coredump "$entry" ;;
      "$PROCESS_EXIT_MESSAGE_ID") handle_process_exit "$entry" ;;
      "$UNIT_FAILED_MESSAGE_ID") handle_unit_failure "$entry" ;;
    esac
  done
}

case ${1:-} in
  --stdin)
    consume
    ;;
  "")
    log "watching service failures and application crashes (herdr at '$working_directory', tmux session '$session')"
    "$journalctl_bin" --follow --lines=0 --output=json \
      "MESSAGE_ID=$COREDUMP_MESSAGE_ID" \
      "MESSAGE_ID=$PROCESS_EXIT_MESSAGE_ID" \
      "MESSAGE_ID=$UNIT_FAILED_MESSAGE_ID" | consume
    ;;
  *)
    printf 'usage: system-failure-watcher [--stdin]\n' >&2
    exit 2
    ;;
esac
