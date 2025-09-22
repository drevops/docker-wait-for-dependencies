#!/bin/bash
set -euo pipefail
[ "${DEBUG:-}" = "1" ] && set -x

SLEEP_LENGTH="${SLEEP_LENGTH:-2}"
TIMEOUT_LENGTH="${TIMEOUT_LENGTH:-300}"
SUMMARY_ENABLED="${SUMMARY_ENABLED:-true}"

is_host_port() {
  local token="$1"

  # Reject if contains protocol, spaces, or slashes
  if [[ $token == *"://"* ]] || [[ $token == *" "* ]] || [[ $token == *"/"* ]]; then
    return 1
  fi

  # Must contain exactly one colon
  if [[ ${token//[^:]/} != ":" ]]; then
    return 1
  fi

  local host="${token%:*}"
  local port="${token#*:}"

  # Host validation: alphanumeric, dots, hyphens, underscores only
  if [[ ! $host =~ ^[A-Za-z0-9._-]+$ ]] || [[ -z $host ]]; then
    return 1
  fi

  # Port validation: numeric only, 1-5 digits, range 1-65535
  if [[ ! $port =~ ^[0-9]{1,5}$ ]] || ((port < 1 || port > 65535)); then
    return 1
  fi

  return 0
}

wait_tcp() {
  local host="$1"
  local port="$2"
  local start_time elapsed_time last_still_waiting=0

  echo "Waiting (tcp): ${host}:${port} …"
  start_time=$(date +%s)

  while ! nc -z "$host" "$port" >/dev/null 2>&1; do
    elapsed_time=$(($(date +%s) - start_time))

    if ((elapsed_time > TIMEOUT_LENGTH)); then
      echo "✗ Timeout after ${TIMEOUT_LENGTH}s (tcp): ${host}:${port}"
      return 1
    fi

    # Print "still waiting" every ~10s, but not on first iteration
    if ((elapsed_time > 0 && elapsed_time % 10 == 0 && elapsed_time != last_still_waiting)); then
      echo "… still waiting (elapsed ${elapsed_time}s, timeout ${TIMEOUT_LENGTH}s)"
      last_still_waiting=$elapsed_time
    fi

    sleep "$SLEEP_LENGTH"
  done

  echo "✓ Ready (tcp): ${host}:${port}"
  return 0
}

wait_cmd() {
  local cmd="$1"
  local start_time elapsed_time last_still_waiting=0

  echo "Waiting (cmd): $cmd …"
  start_time=$(date +%s)

  while ! bash -c "$cmd" >/dev/null 2>&1; do
    elapsed_time=$(($(date +%s) - start_time))

    if ((elapsed_time > TIMEOUT_LENGTH)); then
      echo "✗ Timeout after ${TIMEOUT_LENGTH}s (cmd): $cmd"
      return 1
    fi

    # Print "still waiting" every ~10s, but not on first iteration
    if ((elapsed_time > 0 && elapsed_time % 10 == 0 && elapsed_time != last_still_waiting)); then
      echo "… still waiting (elapsed ${elapsed_time}s, timeout ${TIMEOUT_LENGTH}s)"
      last_still_waiting=$elapsed_time
    fi

    sleep "$SLEEP_LENGTH"
  done

  echo "✓ Ready (cmd): $cmd"
  return 0
}

main() {
  if (($# == 0)); then
    echo "Usage: entrypoint.sh <target> [<target> ...]"
    echo "  target: 'host:port' (tcp) or arbitrary shell command"
    exit 2
  fi

  local target
  for target in "$@"; do
    if is_host_port "$target"; then
      local host="${target%:*}"
      local port="${target#*:}"
      if ! wait_tcp "$host" "$port"; then
        exit 1
      fi
    else
      if ! wait_cmd "$target"; then
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
