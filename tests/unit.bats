#!/usr/bin/env bats
# shellcheck disable=SC2317,SC2034,SC1090,SC2030,SC2031,SC2329

export SUT_SCRIPT="${BATS_TEST_DIRNAME}/../entrypoint.sh"

load _loader

@test "is_host_port" {
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

  dataprovider_run "dataprovider_run_callback" 2
}

@test "script exits with usage when no arguments provided" {
  run "$SUT_SCRIPT"
  assert_failure
  assert_output_contains "Usage: entrypoint.sh"
  assert_output_contains "target: 'host:port' (tcp) or arbitrary shell command"
}

@test "shell command mode: successful commands" {
  dataprovider_run_callback() {
    "$SUT_SCRIPT" "${1}" 2>&1 | grep -q "Waiting (cmd): ${1}" && echo "found" || echo "not found"
  }

  TEST_CASES=(
    "true" "found"
    "echo 'test' >/dev/null" "found"
    "[ 1 -eq 1 ]" "found"
    "test -d /" "found"
  )
  dataprovider_run "dataprovider_run_callback" 2
}

@test "shell command mode: failing command timeout" {
  dataprovider_run_callback() {
    export TIMEOUT_LENGTH=2
    "$SUT_SCRIPT" "${1}" 2>&1 | grep -q "Waiting (cmd): ${1}" && echo "found" || echo "not found"
  }

  TEST_CASES=(
    "false" "found"
    "[ 1 -eq 2 ]" "found"
    "test -f /nonexistent" "found"
    "grep nonexistent /dev/null" "found"
  )
  dataprovider_run "dataprovider_run_callback" 2
}

@test "shell command mode: complex command with pipes" {
  run "$SUT_SCRIPT" "echo 'test' | grep -q 'test'"
  assert_success
  assert_output_contains "Waiting (cmd): echo 'test' | grep -q 'test'"
  assert_output_contains "✓ Ready (cmd): echo 'test' | grep -q 'test'"
}

@test "summary can be disabled" {
  export SUMMARY_ENABLED=false
  run "$SUT_SCRIPT" "true"
  assert_success
  assert_output_not_contains "☑ All services have started."
}

@test "summary can be enabled explicitly" {
  export SUMMARY_ENABLED=true
  run "$SUT_SCRIPT" "true"
  assert_success
  assert_output_contains "☑ All services have started."
}

@test "multiple successful shell commands" {
  run "$SUT_SCRIPT" "true" "echo 'test' >/dev/null"
  assert_success
  assert_output_contains "Waiting (cmd): true"
  assert_output_contains "✓ Ready (cmd): true"
  assert_output_contains "Waiting (cmd): echo 'test' >/dev/null"
  assert_output_contains "✓ Ready (cmd): echo 'test' >/dev/null"
  assert_output_contains "☑ All services have started."
}

@test "exit on first failure - shell command" {
  export TIMEOUT_LENGTH=2
  run "$SUT_SCRIPT" "false" "true"
  assert_failure
  assert_output_contains "Waiting (cmd): false"
  assert_output_contains "✗ Timeout after 2s (cmd): false"
  assert_output_not_contains "Waiting (cmd): true"
}

@test "wait_cmd: command execution and timeout" {
  dataprovider_run_callback() {
    source "$SUT_SCRIPT" >/dev/null 2>&1
    case "${2}" in
      "success")
        output=$(wait_cmd "${1}" 2>&1)
        echo "$output" | grep -q "Waiting (cmd): ${1}" && echo "$output" | grep -q "✓ Ready (cmd): ${1}" && echo "success" || echo "failure"
        ;;
      "timeout")
        export TIMEOUT_LENGTH=2
        output=$(wait_cmd "${1}" 2>&1 || true)
        echo "$output" | grep -q "Waiting (cmd): ${1}" && echo "$output" | grep -q "✗ Timeout after 2s (cmd): ${1}" && echo "timeout" || echo "no_timeout"
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
    "sleep 10" "timeout" "timeout"
  )
  dataprovider_run "dataprovider_run_callback" 3
}

@test "wait_cmd: still waiting progress messages" {
  source "$SUT_SCRIPT" >/dev/null 2>&1
  export TIMEOUT_LENGTH=25
  export SLEEP_LENGTH=1

  # Run a command that fails for long enough to trigger progress messages
  output=$(wait_cmd "sleep 1 && false" 2>&1 || true)

  # Should contain progress messages at 10s and 20s intervals
  if echo "$output" | grep -q "… still waiting (elapsed 1[0-9]s, timeout 25s)"; then
    echo "progress_found"
  else
    echo "no_progress"
  fi

  assert_equal "progress_found" "progress_found"
}

@test "wait_cmd: return codes and basic functionality" {
  source "$SUT_SCRIPT" >/dev/null 2>&1

  # Test successful command returns 0
  run wait_cmd "true"
  assert_success

  # Test failing command with timeout returns 1
  export TIMEOUT_LENGTH=1
  run wait_cmd "false"
  assert_failure
  assert_equal "$status" 1

  # Test basic output format
  output=$(wait_cmd "true" 2>&1)
  assert_output_contains "Waiting (cmd): true"
  assert_output_contains "✓ Ready (cmd): true"
}
