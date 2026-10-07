#!/usr/bin/env bash

set -uo pipefail

readonly COREDUMP_MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1
readonly PROCESS_EXIT_MESSAGE_ID=98e322203f7a4ed290d09fe03c09fe15
readonly UNIT_FAILED_MESSAGE_ID=d9b373ed55a64feb8242e02dbe79a49c
# Transient units the Quickshell launcher starts apps in (launcher/Apps.qml).
readonly APP_UNIT_PREFIX=app-sgiath-
readonly dedupe_seconds=${SYSTEM_FAILURE_WATCHER_DEDUPE_SECONDS:-300}
readonly working_directory=${SYSTEM_FAILURE_WATCHER_WORKING_DIRECTORY:-$HOME/nixos}
readonly t3_bin=${SYSTEM_FAILURE_WATCHER_T3:-t3}
readonly t3_endpoint=${SYSTEM_FAILURE_WATCHER_T3_ENDPOINT:-http://localhost:3773/mcp}
readonly journalctl_bin=${SYSTEM_FAILURE_WATCHER_JOURNALCTL:-journalctl}
readonly jq_bin=${SYSTEM_FAILURE_WATCHER_JQ:-jq}

declare -A last_dispatched
# app unit -> "<exit code> <exit status>"; systemd logs the main process
# exit right before the unit's failure verdict.
declare -A app_exit

log() {
  printf 'system-failure-watcher: %s\n' "$*" >&2
}

# The CLI bridge handles MCP initialization and SSE responses. Credentials
# are minted locally at runtime and expire after five minutes.
t3_call() {
  local reply
  if ! reply=$(timeout 30 "$t3_bin" acp-mcp-call "$1" "$2" 2>&1); then
    log "T3 $1 failed: $reply"
    return 1
  fi
  if ! "$jq_bin" -e '.isError != true' <<<"$reply" >/dev/null 2>&1; then
    log "T3 $1 failed: $reply"
    return 1
  fi
  "$jq_bin" -e '.structuredContent // (.content[]? | select(.type == "text") | .text | fromjson)' <<<"$reply"
}

dispatch_t3() (
  local label=$1 prompt=$2 token page project cursor=0 model payload reply

  if ! token=$("$t3_bin" auth session issue --subject mcp-client \
    --scope orchestration:read --scope orchestration:operate \
    --ttl 5m --label system-failure-watcher --token-only); then
    log "could not issue a local T3 credential"
    return 1
  fi
  export T3_ACP_MCP_ENDPOINT="$t3_endpoint"
  export T3_ACP_MCP_AUTHORIZATION="Bearer $token"

  while :; do
    page=$(t3_call t3_project_list "{\"cursor\":$cursor}") || return 1
    # shellcheck disable=SC2016 # $path is a jq variable.
    project=$("$jq_bin" -c --arg path "$working_directory" \
      '.projects[]? | select(.workspaceRoot == $path)' <<<"$page") || return 1
    [[ -n $project ]] && break
    cursor=$("$jq_bin" -r '.nextCursor // "null"' <<<"$page") || return 1
    if [[ $cursor == null ]]; then
      log "no T3 project registered at '$working_directory'"
      return 1
    fi
  done

  model=$("$jq_bin" -c '.defaultModelSelection // empty' <<<"$project") || return 1
  if [[ -z $model ]]; then
    reply=$(t3_call orchestrator_capabilities '{}') || return 1
    model=$("$jq_bin" -ce '[.providers[] | select(.canRunChildTask and (.models | length > 0))][0] |
      select(. != null) | {provider: .driverKind, instanceId: .providerInstanceId, model: .models[0].id}' \
      <<<"$reply") || {
      log "no available T3 provider/model"
      return 1
    }
  fi

  # shellcheck disable=SC2016 # These are jq variables.
  payload=$("$jq_bin" -cn --argjson project "$project" --argjson model "$model" \
    --arg title "$label" --arg message "$prompt" \
    '{projectId: $project.id, title: $title, message: $message, modelSelection: $model}') || return 1
  reply=$(t3_call t3_thread_launch "$payload") || return 1
  "$jq_bin" -er '.threadId | select(type == "string" and length > 0)' <<<"$reply"
)

dispatch() {
  local key=$1 label=$2 prompt=$3 thread
  local now=${EPOCHSECONDS:-0}
  local last=${last_dispatched[$key]:-0}

  if ((now - last < dedupe_seconds)); then
    log "deduplicated $key"
    return 0
  fi

  label=${label//[^a-zA-Z0-9_.-]/-}
  label=failed-${label:0:40}-$now

  if thread=$(dispatch_t3 "$label" "$prompt"); then
    last_dispatched[$key]=$now
    log "opened T3 thread $thread ($label) for $key"
  else
    log "could not open a T3 thread; skipped $key"
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
  # diagnosis rather than opening a second thread for the same failure.
  # Launcher apps run with ExitType=cgroup, so a dump of something the app
  # forked never becomes a unit failure; hand it over under the same key,
  # which dedupes the case where the main process dumped and both arrive.
  if [[ $unit == "$APP_UNIT_PREFIX"*.service ]]; then
    handle_app_failure "$unit" "a core dump of '$comm' on $signal; start with 'coredumpctl info $pid'"
    return
  fi
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

# $2 describes the ending; the unit verdict handler builds it from the exit
# it remembered, the coredump handler from the dump.
handle_app_failure() {
  local unit=$1 ending=$2 id prompt

  # app-sgiath-<desktop id>-<launch timestamp>.service
  id=${unit#"$APP_UNIT_PREFIX"}
  id=${id%-*}

  prompt="Investigate why the desktop application '$id' died after being launched from the shell launcher on this host. It ran as the transient user unit '$unit' and ended with $ending. The unit is already collected; its output and systemd's verdict are in the journal: 'journalctl --user -u $unit --no-pager'. Find the '$id.desktop' entry through XDG_DATA_DIRS for the exact command line. Establish the root cause and fix it in this NixOS repository when the failure is configuration-owned (missing dependency, environment, wrapper, package option). Do not merely relaunch the application or suppress the error. If the fault is upstream, collect enough evidence for a useful upstream report."

  dispatch "app:$id" "$id" "$prompt"
}

handle_app_unit_failure() {
  local unit=$1 result=$2 code status

  read -r code status <<<"${app_exit[$unit]:-- -}"
  unset "app_exit[$unit]"

  # SIGKILL is the user's doing (forcekillactive, kill -9); systemd already
  # counts TERM/INT/HUP/PIPE as clean exits, and an OOM kill carries its own
  # result so it still gets through.
  [[ $result == signal && $status == 9 ]] && return 0

  handle_app_failure "$unit" "result '$result' (main process $code, status $status)"
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
    handle_app_unit_failure "$unit" "$result"
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
    log "watching service failures and application crashes (T3 project at '$working_directory')"
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
