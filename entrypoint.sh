#!/usr/bin/env bash
set -euo pipefail
[[ ${DEBUG:-} == "1" ]] && set -x

SLEEP_LENGTH="${SLEEP_LENGTH:-2}"
TIMEOUT_LENGTH="${TIMEOUT_LENGTH:-300}"
SUMMARY_ENABLED="${SUMMARY_ENABLED:-true}"

is_host_port() {
  local target="${1}"

  if [[ ${target} == *"://"* ]] || [[ ${target} == *" "* ]] || [[ ${target} == *"/"* ]]; then
    return 1
  fi

  # Must contain exactly 1 colon
  if [[ ${target//[^:]/} != ":" ]]; then
    return 1
  fi

  local host="${target%:*}"
  local port="${target#*:}"

  if [[ ! ${host} =~ ^[A-Za-z0-9._-]+$ ]] || [[ -z ${host} ]]; then
    return 1
  fi

  # Bash arithmetic reads a leading zero as octal, so force base 10.
  if [[ ! ${port} =~ ^[0-9]{1,5}$ ]] || ((10#${port} < 1 || 10#${port} > 65535)); then
    return 1
  fi

  return 0
}

stop_probe_after() {
  local seconds="${1}"
  local pgid="${2}"

  sleep "${seconds}"

  # A probe can ignore SIGTERM or trap it and exit 0, so it gets SIGKILL.
  kill -KILL -- "-${pgid}" 2>/dev/null || true
}

run_probe() {
  local seconds="${1}"
  shift
  local probe_pid watchdog_pid status=0

  if ((seconds < 1)); then
    seconds=1
  fi

  # Job control puts each background job in its own process group, so a
  # signal to the group also reaches the processes the job started.
  set -m
  "$@" </dev/null >/dev/null 2>&1 &
  probe_pid=$!
  stop_probe_after "${seconds}" "${probe_pid}" &
  watchdog_pid=$!
  set +m

  wait "${probe_pid}" 2>/dev/null || status=$?

  # Kill the watchdog and anything the probe left running. A group signal
  # can miss a child that is being forked, so both groups get a second
  # SIGKILL once the watchdog has exited.
  kill -KILL -- "-${watchdog_pid}" "-${probe_pid}" 2>/dev/null || true
  wait "${watchdog_pid}" 2>/dev/null || true
  kill -KILL -- "-${watchdog_pid}" "-${probe_pid}" 2>/dev/null || true

  return "${status}"
}

wait_probe() {
  local kind="${1}"
  local label="${2}"
  shift 2
  local start_time elapsed_time=0 last_still_waiting=0

  echo "Waiting (${kind}): ${label} …"
  start_time=$(date +%s)

  while ! run_probe "$((TIMEOUT_LENGTH - elapsed_time))" "$@"; do
    elapsed_time=$(($(date +%s) - start_time))

    if ((elapsed_time >= TIMEOUT_LENGTH)); then
      echo "✗ Timeout after ${TIMEOUT_LENGTH}s (${kind}): ${label}"
      return 1
    fi

    if ((elapsed_time - last_still_waiting >= 10)); then
      echo "… still waiting (${kind}): ${label} (elapsed ${elapsed_time}s, timeout ${TIMEOUT_LENGTH}s)"
      last_still_waiting=${elapsed_time}
    fi

    sleep "${SLEEP_LENGTH}"
    elapsed_time=$(($(date +%s) - start_time))
  done

  echo "✓ Ready (${kind}): ${label}"
  return 0
}

wait_tcp() {
  local host="${1}"
  local port="${2}"

  wait_probe tcp "${host}:${port}" nc -z "${host}" "${port}"
}

wait_cmd() {
  local cmd="${1}"

  wait_probe cmd "${cmd}" bash -c "${cmd}"
}

main() {
  if (($# == 0)); then
    echo "Usage: entrypoint.sh <target> [<target> ...]"
    echo "  target: 'host:port' (tcp) or arbitrary shell command"
    exit 2
  fi

  local target

  for target in "$@"; do
    if is_host_port "${target}"; then
      wait_tcp "${target%:*}" "${target#*:}" || exit 1
    else
      wait_cmd "${target}" || exit 1
    fi
  done

  if [[ ${SUMMARY_ENABLED} == "true" ]]; then
    echo "☑ All services have started."
  fi
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
