#!/usr/bin/env bash
# shellcheck disable=SC1090

setup() {
  # Register a path to libraries.
  export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/../node_modules"

  export FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

  # Load 'bats-helpers' library.
  ASSERT_DIR_EXCLUDE=("vortex" ".data")
  export ASSERT_DIR_EXCLUDE
  bats_load_library bats-helpers

  # Setup command mocking.
  setup_mock

  if [ -n "${SUT_SCRIPT-}" ]; then
    [ ! -f "${SUT_SCRIPT}" ] && echo "SUT_SCRIPT file not found: ${SUT_SCRIPT}" && exit 1
    export TIMEOUT_LENGTH=1
    source "${SUT_SCRIPT}"
  fi

  container_cleanup
}

teardown() {
  container_cleanup
}

container_cleanup() {
  docker compose -f docker-compose.tcp.yml down -v --remove-orphans >/dev/null 2>&1 || true
  docker compose -f docker-compose.cmd.yml down -v --remove-orphans >/dev/null 2>&1 || true
}

step() {
  echo "> ${1}" >&3
}

wait_for_cmd() {
  local timeout=${1:-30}
  local sleep_time=${2:-2}
  shift 2
  local cmd=("$@")

  echo -n "    Waiting up to ${timeout}s for command to succeed: ${cmd[*]}" >&3

  local start elapsed
  start=$(date +%s)
  while true; do
    if "${cmd[@]}" >/dev/null 2>&1; then
      echo "✓" >&3
      return 0
    fi

    elapsed=$(($(date +%s) - start))
    if ((elapsed > timeout)); then
      echo "✗ Timeout after ${timeout}s: ${cmd[*]}" >&3
      return 1
    fi

    echo -n "." >&3
    sleep "$sleep_time"
  done
}
