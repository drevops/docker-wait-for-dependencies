#!/bin/bash

SLEEP_LENGTH=${SLEEP_LENGTH:-2}
TIMEOUT_LENGTH=${TIMEOUT_LENGTH:-300}

wait_for() {
  local host=$1
  local port=$2
  local start_time

  echo "Waiting for $host to listen on port $port..."

  start_time=$(date +%s)
  while ! nc -z "$host" "$port"; do
    local elapsed_time=$(($(date +%s) - start_time))

    if ((elapsed_time > TIMEOUT_LENGTH)); then
      echo "Service $host:$port did not start within $TIMEOUT_LENGTH seconds. Aborting..."
      exit 1
    fi

    echo "Sleeping for $SLEEP_LENGTH seconds..."
    sleep "$SLEEP_LENGTH"
  done

  echo "$host is listening on port $port"
}

for arg in "$@"; do
  host=${arg%:*}
  port=${arg#*:}
  wait_for "$host" "$port"
done
