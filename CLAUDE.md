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
- **`entrypoint.sh`**: Main shell script containing all logic (lines 95-125 in main function)
  - `is_host_port()` function: Validates host:port format with strict regex validation
  - `wait_tcp()` function: Uses netcat for TCP connectivity checks  
  - `wait_cmd()` function: Executes shell commands for custom health checks
- **`Dockerfile`**: Minimal Alpine 3.22.1 base with bash and curl
- **Test fixtures**: Docker Compose files for TCP (`docker-compose.tcp.yml`) and command-based (`docker-compose.cmd.yml`) testing

### Environment Variables
- `SLEEP_LENGTH` (default: 2): Seconds between check attempts
- `TIMEOUT_LENGTH` (default: 300): Maximum wait time before timeout
- `SUMMARY_ENABLED` (default: true): Show completion summary

## Development Commands

### Linting and Formatting
```bash
npm run lint      # Run shellcheck, shfmt, and hadolint on all files
npm run lint-fix  # Auto-fix shell script formatting with shfmt
```

### Testing
```bash
npm run test-unit       # Run unit tests with BATS (tests/unit.bats)
npm run test-functional # Run functional tests with Docker Compose (tests/functional.bats)
```

Unit tests focus on the `is_host_port()` validation function using extensive data provider patterns. Functional tests use Docker Compose to verify real TCP and command-based waiting scenarios.

### Test Framework
- **BATS** (Bash Automated Testing System) with `@drevops/bats-helpers` library
- **Test structure**: `tests/_loader.bash` provides setup/teardown and utilities
- **Docker integration**: Tests build and run the container with test services
- **Fixtures**: Separate compose files for TCP vs command testing scenarios

## Container Usage Patterns

The container is designed to be used as a dependency gate in Docker Compose:

```yaml
wait-for-dependencies:
  image: drevops/docker-wait-for-dependencies:latest
  depends_on: [service1, service2]
  command: service1:5432 service2:6379 "curl -f http://api:8080/health"
```

## Release Process

- GitHub Actions automatically publish Docker images on new releases
- Multi-architecture support: `linux/amd64` and `linux/arm64`
- Versioning follows semantic versioning (e.g., `23.12.0`)