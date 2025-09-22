#!/usr/bin/env bats

load _loader

@test "tcp" {
  pushd "${FIXTURES_DIR}" >/dev/null || exit 1

  step "Start the stack"
  run docker compose -f docker-compose.tcp.yml up -d --build --force-recreate
  assert_success

  step "Wait for the wait-for-dependencies container to exit."
  wait_for_cmd 30 2 bash -c "docker compose -f docker-compose.cmd.yml ps --status=exited | grep wait-for-dependencies"

  step "Assert that the services are running."
  run docker compose -f docker-compose.cmd.yml ps --status=running
  assert_success
  assert_output_contains "service1"
  assert_output_contains "service2"
  assert_output_not_contains "wait-for-dependencies"

  step "Assert the logs content."
  run docker compose -f docker-compose.cmd.yml logs
  assert_success

  assert_output_contains "[service1] Sleeping for 5s before listening"
  assert_output_contains "[service1] Starting netcat listener on port 8001 after sleep for 5s"
  assert_output_contains "✓ Ready (tcp): service1:8001"

  assert_output_contains "[service2] Sleeping for 10s before listening"
  assert_output_contains "[service2] Starting netcat listener on port 8002 after sleep for 10s"
  assert_output_contains "✓ Ready (tcp): service2:8002"

  assert_output_contains "☑ All services have started."

  popd >/dev/null || exit 1
}

@test "cmd" {
  pushd "${FIXTURES_DIR}" >/dev/null || exit 1

  step "Start the stack"
  run docker compose -f docker-compose.cmd.yml up -d --build --force-recreate
  assert_success

  step "Wait for the wait-for-dependencies container to exit."
  wait_for_cmd 30 2 bash -c "docker compose -f docker-compose.cmd.yml ps --status=exited | grep wait-for-dependencies"

  step "Assert that the services are running."
  run docker compose -f docker-compose.cmd.yml ps --status=running
  assert_success
  assert_output_contains "service1"
  assert_output_contains "service2"
  assert_output_not_contains "wait-for-dependencies"

  step "Assert the logs content."
  run docker compose -f docker-compose.cmd.yml logs
  assert_success

  assert_output_contains "[service1] Sleeping for 5s before listening..."
  assert_output_contains "No syntax errors detected in /tmp/server.php"
  assert_output_contains "[service1] Starting PHP built-in server on port 8001 after sleep for 5s"
  assert_output_contains "Development Server (http://0.0.0.0:8001) started"
  assert_output_contains "✓ Ready (tcp): service1:8001"
  assert_output_contains "Waiting (cmd): curl -f http://service1:8001/status | grep OK"
  assert_output_contains "PHP server request: /status"
  assert_output_contains 'PHP server response: {"status":"healthy","service":"service1","message":"OK status"}'
  assert_output_contains "✓ Ready (cmd): curl -f http://service1:8001/status | grep OK"

  assert_output_contains "[service2] Sleeping for 10s before listening..."
  assert_output_contains "[service2] Starting netcat listener on port 8002 after sleep for 10s"
  assert_output_contains "✓ Ready (tcp): service2:8002"

  assert_output_contains "☑ All services have started."

  popd >/dev/null || exit 1
}
