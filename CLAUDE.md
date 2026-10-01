# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker wait for dependencies is a containerized tool that waits for services to be ready before proceeding. It supports:
- **TCP connectivity checks**: Wait for services via `host:port` format
- **Shell command health checks**: Execute arbitrary commands and wait for success
- **Configurable timeouts and intervals**: Environment variable control

The project creates a minimal Alpine Linux Docker image (`drevops/docker-wait-for-dependencies`) used in Docker Compose workflows to ensure service dependencies are ready before starting dependent services.

## Architecture

### Core Components
- **`entrypoint.sh`**: Main shell script containing all logic
  - `is_host_port()` function: Validates host:port format with strict regex validation
  - `stop_probe_after()` function: Watchdog that sends `SIGKILL` to a probe's process group once its time is up, so a probe that traps `SIGTERM` can't exit 0 and pass as ready
  - `run_probe()` function: Runs 1 attempt in its own process group (`set -m`) with a `stop_probe_after()` watchdog, returns the probe's exit status, and kills whatever the attempt left running; every attempt gets at least 1s
  - `wait_probe()` function: Shared poll loop that retries a probe through `run_probe()`, capping each attempt at the time left, until it succeeds or `TIMEOUT_LENGTH` passes, with a "still waiting" notice at most once every 10s
  - `wait_tcp()` function: Checks TCP connectivity with `nc -z` through `wait_probe()`
  - `wait_cmd()` function: Runs a shell command health check with `bash -c` through `wait_probe()`
- **`Dockerfile`**: Minimal Alpine base with bash and curl
- **Test fixtures**: Docker Compose files for TCP (`docker-compose.tcp.yml`) and command-based (`docker-compose.cmd.yml`) testing

### Environment Variables
- `SLEEP_LENGTH` (default: 2): Seconds between check attempts
- `TIMEOUT_LENGTH` (default: 300): Wait time for each target; an attempt still running when it passes is stopped, and the attempt after the last sleep always gets at least 1s, so a target can overrun by up to `SLEEP_LENGTH` + 1s
- `SUMMARY_ENABLED` (default: true): Show completion summary
- `DEBUG` (default: unset): Set to `1` to trace every command with `set -x`

## Development Commands

### Linting and Formatting
```bash
npm run lint      # Run shellcheck, shfmt, and hadolint on all files
npm run lint-fix  # Auto-fix shell script formatting with shfmt
```

### Testing
```bash
npm run test-unit       # Run unit tests with BATS (tests/unit.bats)
npm run test-coverage   # Run unit tests under kcov, writing .coverage-html (what CI runs)
npm run test-functional # Run functional tests with Docker Compose (tests/functional.bats)
```

Unit tests cover `is_host_port()` validation, `run_probe()` exit statuses, probes stopped at the timeout along with their child processes, `wait_tcp()` and `wait_cmd()` with mocked `nc` and `date`, and the entrypoint's exit codes and summary, using data providers where cases repeat. Leak checks run the call inside `$(...)` with FD 4 duplicated onto the capture, so the substitution only returns once every probe process has exited. Functional tests use Docker Compose to verify real TCP and command-based waiting scenarios, including a command still running at the timeout.

### Test Framework
- **BATS** (Bash Automated Testing System) with `@drevops/bats-helpers` library
- **Test structure**: `tests/_loader.bash` provides `setup()`, the `container_cleanup()` helper and utilities; `tests/functional.bats` runs the cleanup before the suite and after each test
- **Docker integration**: Tests build and run the container with test services
- **Fixtures**: Separate compose files for TCP vs command testing scenarios

### Continuous Integration
- The `test` job in `test.yml` runs on a bare `ubuntu-latest` runner. It lints with `luizm/action-sh-checker` (ShellCheck and shfmt) and `hadolint/hadolint-action` instead of `npm run lint`, then runs the same `npm run test-coverage` and `npm run test-functional` scripts listed above
- The `SHFMT_OPTS` passed to `luizm/action-sh-checker` must match the `shfmt` flags in the `lint` and `lint-fix` scripts in `package.json`, so CI and `npm run lint` check formatting the same way
- It installs Node.js 24 with `actions/setup-node` and builds kcov from source outside the workspace, since no action installs kcov
- `KCOV_VERSION` sits in the kcov step's `env` under a `# renovate:` comment, so Renovate bumps it through the `customManagers:githubActionsVersions` preset

## Container Usage Patterns

The container is designed to be used as a dependency gate in Docker Compose:

```yaml
wait-for-dependencies:
  image: drevops/docker-wait-for-dependencies:latest
  depends_on: [service1, service2]
  command: service1:5432 service2:6379 "curl -f http://api:8080/health"
```

## Release Process

- `draft-release-notes.yml` drafts the next release on every push to `main`; the `RELEASE_VERSION_SCHEME` repository variable is `calver`, so drafts are named `YY.M.0`
- `release-docker.yml` builds and pushes the image for `linux/amd64` and `linux/arm64` on every tag push
- `test.yml` pushes the `canary` image after tests pass on `main`
- Versioning follows CalVer `YY.M.patch` (e.g., `26.10.0`)
