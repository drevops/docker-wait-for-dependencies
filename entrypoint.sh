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

  if [[ ! ${port} =~ ^[0-9]{1,5}$ ]] || ((port < 1 || port > 65535)); then
    return 1
  fi

  return 0
}

wait_probe() {
  local kind="${1}"
  local label="${2}"
  shift 2
  local start_time elapsed_time last_still_waiting=0

  echo "Waiting (${kind}): ${label} …"
  start_time=$(date +%s)

  while ! "$@" >/dev/null 2>&1; do
    elapsed_time=$(($(date +%s) - start_time))

    if ((elapsed_time > TIMEOUT_LENGTH)); then
      echo "✗ Timeout after ${TIMEOUT_LENGTH}s (${kind}): ${label}"
      return 1
    fi

    if ((elapsed_time - last_still_waiting >= 10)); then
      echo "… still waiting (${kind}): ${label} (elapsed ${elapsed_time}s, timeout ${TIMEOUT_LENGTH}s)"
      last_still_waiting=${elapsed_time}
    fi

    sleep "${SLEEP_LENGTH}"
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
      local host="${target%:*}"
      local port="${target#*:}"
      if ! wait_tcp "${host}" "${port}"; then
        exit 1
      fi
    else
      if ! wait_cmd "${target}"; then
        exit 1
      fi
    fi
  done

  if [[ ${SUMMARY_ENABLED} == "true" ]]; then
    echo "☑ All services have started."
  fi
}

# Only run main if script is executed directly (not sourced)
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
