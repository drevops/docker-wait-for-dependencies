#!/usr/bin/env bats
# shellcheck disable=SC2317,SC2034,SC2030,SC2031,SC2329

export SUT_SCRIPT="${BATS_TEST_DIRNAME}/../entrypoint.sh"

load _loader

@test "is_host_port: valid and invalid targets" {
  dataprovider_run_callback() {
    is_host_port "${1}" && echo "success" || echo "failure"
  }

  TEST_CASES=(
    # Valid combinations
    "localhost:3000" "success"
    "redis:6379" "success"
    "db.example.com:5432" "success"
    "192.168.1.1:80" "success"
    "service-name:8080" "success"
    "test_host:1" "success"
    "test_host:65535" "success"
    "my-service.namespace:9000" "success"
    "app123:22" "success"
    "web.local:443" "success"

    # Invalid with protocols
    "http://example.com:8080" "failure"
    "https://example.com:443" "failure"
    "tcp://localhost:3000" "failure"
    "ftp://server:21" "failure"
    "ws://localhost:8080" "failure"

    # Invalid with spaces
    "host with spaces:3000" "failure"
    "localhost:30 00" "failure"
    " localhost:3000" "failure"
    "localhost:3000 " "failure"
    "my host:8080" "failure"

    # Invalid with paths
    "host/path:3000" "failure"
    "localhost:3000/path" "failure"
    "example.com/api:80" "failure"
    "server/endpoint:443" "failure"

    # Invalid port numbers
    "localhost:99999" "failure"
    "localhost:0" "failure"
    "localhost:abc" "failure"
    "localhost:" "failure"
    "localhost:123456" "failure"
    "localhost:-1" "failure"
    "localhost:port" "failure"
    "localhost:3000a" "failure"
    "localhost:65536" "failure"

    # Ports with leading zeros, read as decimal
    "localhost:08080" "success"
    "localhost:09" "success"
    "localhost:0080" "success"
    "localhost:09999" "success"
    "localhost:010" "success"
    "localhost:01" "success"
    "localhost:00001" "success"
    "localhost:00" "failure"
    "localhost:00000" "failure"
    "localhost:065535" "failure"

    # Invalid host names
    ":3000" "failure"
    "host@name:3000" "failure"
    "host#name:3000" "failure"
    "host%name:3000" "failure"
    "host&name:3000" "failure"
    "host=name:3000" "failure"
    "host+name:3000" "failure"

    # Invalid colon usage
    "localhost" "failure"
    "localhost:30:00" "failure"
    "host:port:extra" "failure"
    "::3000" "failure"
    "host::" "failure"
  )

  # Match exactly, so a case also fails when is_host_port() prints anything.
  dataprovider_run "dataprovider_run_callback" 2 assert_output
}

@test "entrypoint: exits with usage when no arguments are provided" {
  run "${SUT_SCRIPT}"
  assert_failure
  assert_output_contains "Usage: entrypoint.sh"
  assert_output_contains "target: 'host:port' (tcp) or arbitrary shell command"
}

@test "entrypoint: successful shell commands" {
  dataprovider_run_callback() {
    local result
    result=$("${SUT_SCRIPT}" "${1}" 2>&1) || true
    [[ ${result} == *"✓ Ready (cmd): ${1}"* ]] && echo "ready" || echo "missing"
  }

  TEST_CASES=(
    "true" "ready"
    "echo 'test' >/dev/null" "ready"
    "[ 1 -eq 1 ]" "ready"
    "test -d /" "ready"
  )
  dataprovider_run "dataprovider_run_callback" 2
}

@test "entrypoint: failing shell commands time out" {
  dataprovider_run_callback() {
    export TIMEOUT_LENGTH=2
    local result
    result=$("${SUT_SCRIPT}" "${1}" 2>&1) || true
    [[ ${result} == *"✗ Timeout after 2s (cmd): ${1}"* ]] && echo "timeout" || echo "missing"
  }

  TEST_CASES=(
    "false" "timeout"
    "[ 1 -eq 2 ]" "timeout"
    "test -f /nonexistent" "timeout"
    "grep nonexistent /dev/null" "timeout"
  )
  dataprovider_run "dataprovider_run_callback" 2
}

@test "entrypoint: shell command with pipes" {
  run "${SUT_SCRIPT}" "echo 'test' | grep -q 'test'"
  assert_success
  assert_output_contains "Waiting (cmd): echo 'test' | grep -q 'test'"
  assert_output_contains "✓ Ready (cmd): echo 'test' | grep -q 'test'"
}

@test "entrypoint: summary can be disabled" {
  export SUMMARY_ENABLED=false
  run "${SUT_SCRIPT}" "true"
  assert_success
  assert_output_not_contains "☑ All services have started."
}

@test "entrypoint: summary can be enabled explicitly" {
  export SUMMARY_ENABLED=true
  run "${SUT_SCRIPT}" "true"
  assert_success
  assert_output_contains "☑ All services have started."
}

@test "entrypoint: multiple successful shell commands" {
  run "${SUT_SCRIPT}" "true" "echo 'test' >/dev/null"
  assert_success
  assert_output_contains "Waiting (cmd): true"
  assert_output_contains "✓ Ready (cmd): true"
  assert_output_contains "Waiting (cmd): echo 'test' >/dev/null"
  assert_output_contains "✓ Ready (cmd): echo 'test' >/dev/null"
  assert_output_contains "☑ All services have started."
}

@test "entrypoint: exits on the first failing shell command" {
  export TIMEOUT_LENGTH=2
  run "${SUT_SCRIPT}" "false" "true"
  assert_failure
  assert_output_contains "Waiting (cmd): false"
  assert_output_contains "✗ Timeout after 2s (cmd): false"
  assert_output_not_contains "Waiting (cmd): true"
}

@test "entrypoint: tcp target ready" {
  mock_nc=$(mock_command nc)
  mock_set_status "${mock_nc}" 0
  run "${SUT_SCRIPT}" "myhost:1234"
  assert_success
  assert_output_contains "Waiting (tcp): myhost:1234"
  assert_output_contains "✓ Ready (tcp): myhost:1234"
  assert_output_contains "☑ All services have started."
}

@test "entrypoint: mixed tcp and shell command targets" {
  mock_nc=$(mock_command nc)
  mock_set_status "${mock_nc}" 0
  run "${SUT_SCRIPT}" "myhost:1234" "true"
  assert_success
  assert_output_contains "✓ Ready (tcp): myhost:1234"
  assert_output_contains "Waiting (cmd): true"
  assert_output_contains "✓ Ready (cmd): true"
  assert_output_contains "☑ All services have started."
}

@test "entrypoint: exits on the first failing tcp target" {
  mock_nc=$(mock_command nc)
  mock_set_status "${mock_nc}" 1
  export TIMEOUT_LENGTH=1
  run "${SUT_SCRIPT}" "myhost:1234" "true"
  assert_failure
  assert_output_contains "Waiting (tcp): myhost:1234"
  assert_output_contains "✗ Timeout after 1s (tcp): myhost:1234"
  assert_output_not_contains "Waiting (cmd): true"
}

@test "run_probe: returns the command exit status" {
  dataprovider_run_callback() {
    local status=0
    run_probe "${1}" bash -c "${2}" || status=$?
    echo "status ${status}"
  }

  TEST_CASES=(
    30 "exit 0" "status 0"
    30 "exit 3" "status 3"
    # Stopped with SIGKILL, even when the command traps SIGTERM.
    1 "sleep 30" "status 137"
    1 "trap 'exit 0' TERM; sleep 30" "status 137"
  )
  dataprovider_run "dataprovider_run_callback" 3
}

@test "wait_probe: stops a probe still running at the timeout" {
  dataprovider_run_callback() {
    local kind="${1}"
    local script="${2}"
    local result

    export TIMEOUT_LENGTH=1
    SECONDS=0

    # Probe processes inherit FD 4, so the capture stays open until all
    # of them exit.
    if [[ ${kind} == "tcp" ]]; then
      mock_nc=$(mock_command nc)
      mock_set_side_effect "${mock_nc}" "${script}"
      result=$(wait_tcp "myhost" 1234 2>&1 4>&1) || true
    else
      result=$(wait_cmd "${script}" 2>&1 4>&1) || true
    fi

    [[ ${result} == *"✗ Timeout after 1s (${kind}): "* ]] && ((SECONDS < 5)) && echo "stopped" || echo "running"
  }

  TEST_CASES=(
    "cmd" "sleep 30" "stopped"
    "cmd" "sleep 30 | cat" "stopped"
    "cmd" "sleep 30 & wait" "stopped"
    "cmd" "trap '' TERM; sleep 30" "stopped"
    "cmd" "trap 'exit 0' TERM; sleep 30" "stopped"
    "cmd" "sleep 30 & false" "stopped"
    "tcp" "sleep 30" "stopped"
    "tcp" "trap 'exit 0' TERM; sleep 30" "stopped"
  )
  dataprovider_run "dataprovider_run_callback" 3
}

@test "wait_cmd: command execution and timeout" {
  dataprovider_run_callback() {
    local result
    case "${2}" in
      "success")
        result=$(wait_cmd "${1}" 2>&1) || true
        [[ ${result} == *"Waiting (cmd): ${1}"* && ${result} == *"✓ Ready (cmd): ${1}"* ]] && echo "success" || echo "failure"
        ;;
      "timeout")
        export TIMEOUT_LENGTH=2
        result=$(wait_cmd "${1}" 2>&1) || true
        [[ ${result} == *"Waiting (cmd): ${1}"* && ${result} == *"✗ Timeout after 2s (cmd): ${1}"* ]] && echo "timeout" || echo "completed"
        ;;
    esac
  }

  TEST_CASES=(
    # Successful commands
    "true" "success" "success"
    "echo 'test' >/dev/null" "success" "success"
    "[ 1 -eq 1 ]" "success" "success"
    "test -d /" "success" "success"
    # Timeout commands
    "false" "timeout" "timeout"
    "[ 1 -eq 2 ]" "timeout" "timeout"
    "test -f /nonexistent" "timeout" "timeout"
    # Still running when the timeout passes.
    "sleep 10" "timeout" "timeout"
  )
  dataprovider_run "dataprovider_run_callback" 3
}

@test "wait_cmd: still waiting names the command" {
  # Mock 'date' so elapsed time reaches the 10s progress mark and then
  # the timeout. The test then runs without real sleeping or wall-clock
  # timing, so it is instant and deterministic.
  mock_date=$(mock_command date)
  mock_set_output "${mock_date}" 1000 1
  mock_set_output "${mock_date}" 1010 2
  mock_set_output "${mock_date}" 1010 3
  mock_set_output "${mock_date}" 1011 4

  export TIMEOUT_LENGTH=11
  export SLEEP_LENGTH=0

  run wait_cmd "false"

  assert_failure
  assert_output_contains "… still waiting (cmd): false (elapsed 10s, timeout 11s)"
  assert_output_contains "✗ Timeout after 11s (cmd): false"
}

@test "wait_cmd: still waiting prints off the 10s mark" {
  # Mock 'date' so elapsed time at the first check is 12s, not a multiple
  # of 10.
  mock_date=$(mock_command date)
  mock_set_output "${mock_date}" 1000 1
  mock_set_output "${mock_date}" 1012 2
  mock_set_output "${mock_date}" 1012 3
  mock_set_output "${mock_date}" 1013 4

  export TIMEOUT_LENGTH=13
  export SLEEP_LENGTH=0

  run wait_cmd "false"

  assert_failure
  assert_output_contains "… still waiting (cmd): false (elapsed 12s, timeout 13s)"
  assert_output_contains "✗ Timeout after 13s (cmd): false"
}

@test "wait_cmd: return codes and basic functionality" {
  run wait_cmd "true"
  assert_success

  export TIMEOUT_LENGTH=1
  run wait_cmd "false"
  assert_failure
  assert_equal "${status}" 1

  run wait_cmd "true"
  assert_success
  assert_output_contains "Waiting (cmd): true"
  assert_output_contains "✓ Ready (cmd): true"
}

@test "wait_cmd: returns as soon as the command succeeds" {
  dataprovider_run_callback() {
    local result

    export TIMEOUT_LENGTH=30
    SECONDS=0

    # Probe processes inherit FD 4, so the capture stays open until all
    # of them exit.
    result=$(wait_cmd "${1}" 2>&1 4>&1) || true

    [[ ${result} == *"✓ Ready (cmd): ${1}"* ]] && ((SECONDS < 5)) && echo "ready" || echo "slow"
  }

  TEST_CASES=(
    "true" "ready"
    "sleep 30 &" "ready"
  )
  dataprovider_run "dataprovider_run_callback" 2
}

@test "wait_cmd: limits each attempt to the time left" {
  dataprovider_run_callback() {
    local marker="${BATS_TEST_TMPDIR}/attempted-${1}"
    local result

    # The first attempt fails at once, so the mocked clock sets the time
    # left for the second attempt.
    mock_date=$(mock_command date)
    mock_set_output "${mock_date}" 1000 1
    mock_set_output "${mock_date}" 1005 2
    mock_set_output "${mock_date}" "${1}" 3
    mock_set_output "${mock_date}" 1013 4

    export TIMEOUT_LENGTH=10
    export SLEEP_LENGTH=0
    SECONDS=0

    result=$(wait_cmd "[ -f '${marker}' ] || { touch '${marker}'; exit 1; }; ${2}" 2>&1) || true

    if [[ ${result} == *"✓ Ready (cmd): "* ]]; then
      echo "ready"
    elif [[ ${result} == *"✗ Timeout after 10s (cmd): "* ]] && ((SECONDS < 5)); then
      echo "stopped"
    else
      echo "overran"
    fi
  }

  TEST_CASES=(
    # 1s left, so the second attempt is stopped after 1s.
    1009 "sleep 30" "stopped"
    # No time left, and the second attempt still gets 1s.
    1010 "sleep 0.2" "ready"
    1012 "sleep 0.2" "ready"
  )
  dataprovider_run "dataprovider_run_callback" 3
}

@test "wait_tcp: connection check and timeout" {
  mock_nc=$(mock_command nc)

  mock_set_status "${mock_nc}" 0
  run wait_tcp "myhost" 1234
  assert_success
  assert_output_contains "Waiting (tcp): myhost:1234"
  assert_output_contains "✓ Ready (tcp): myhost:1234"

  mock_set_status "${mock_nc}" 1
  export TIMEOUT_LENGTH=1
  run wait_tcp "myhost" 1234
  assert_failure
  assert_output_contains "Waiting (tcp): myhost:1234"
  assert_output_contains "✗ Timeout after 1s (tcp): myhost:1234"
}

@test "wait_tcp: still waiting names the service" {
  mock_nc=$(mock_command nc)
  mock_set_status "${mock_nc}" 1

  # Mock 'date' so elapsed time reaches the 10s progress mark and then
  # the timeout. The test then runs without real sleeping or wall-clock
  # timing, so it is instant and deterministic.
  mock_date=$(mock_command date)
  mock_set_output "${mock_date}" 1000 1
  mock_set_output "${mock_date}" 1010 2
  mock_set_output "${mock_date}" 1010 3
  mock_set_output "${mock_date}" 1011 4

  export TIMEOUT_LENGTH=11
  export SLEEP_LENGTH=0

  run wait_tcp "myhost" 1234

  assert_failure
  assert_output_contains "… still waiting (tcp): myhost:1234 (elapsed 10s, timeout 11s)"
  assert_output_contains "✗ Timeout after 11s (tcp): myhost:1234"
}

@test "wait_tcp: return codes and basic functionality" {
  mock_nc=$(mock_command nc)

  mock_set_status "${mock_nc}" 0
  run wait_tcp "myhost" 1234
  assert_success

  mock_set_status "${mock_nc}" 1
  export TIMEOUT_LENGTH=1
  run wait_tcp "myhost" 1234
  assert_failure
  assert_equal "${status}" 1
}
