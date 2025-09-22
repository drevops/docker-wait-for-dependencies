<p align="center">
  <a href="" rel="noopener">
  <img width=150px height=150px src="logo.png" alt="Wait for dependencies logo"></a>
</p>

<h1 align="center">Docker wait for dependencies</h1>

<div align="center">

[![GitHub Issues](https://img.shields.io/github/issues/DrevOps/docker-wait-for-dependencies.svg)](https://github.com/DrevOps/docker-wait-for-dependencies/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/DrevOps/docker-wait-for-dependencies.svg)](https://github.com/DrevOps/docker-wait-for-dependencies/pulls)
[![Test](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml/badge.svg)](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/drevops/docker-wait-for-dependencies/graph/badge.svg?token=BZK6852630)](https://codecov.io/gh/drevops/docker-wait-for-dependencies)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/DrevOps/docker-wait-for-dependencies)
![LICENSE](https://img.shields.io/github/license/DrevOps/docker-wait-for-dependencies)
![Renovate](https://img.shields.io/badge/renovate-enabled-green?logo=renovatebot)

[![Docker Pulls](https://img.shields.io/docker/pulls/drevops/docker-wait-for-dependencies?logo=docker)](https://hub.docker.com/r/drevops/docker-wait-for-dependencies)
![amd64](https://img.shields.io/badge/arch-linux%2Famd64-brightgreen)
![arm64](https://img.shields.io/badge/arch-linux%2Farm64-brightgreen)

</div>

---

<p align="center">
  Wait for container healthchecks before proceeding.
  <br>
  Available for <code>linux/amd64</code> and <code>linux/arm64</code> architectures.
  <br>
</p>

## Features

- **TCP connectivity**: Wait for services to be accessible via TCP (using
  `host:port` format)
- **Shell command**: Execute arbitrary shell commands and wait for successful
  completion
- **Configurable timeouts**: Customizable sleep intervals and timeout periods
- **User-friendly output**: Clear progress indicators and status messages
- **Multi-architecture support**: Available for `linux/amd64` and `linux/arm64`

## Example usage:

### TCP Connectivity

Wait for services to accept TCP connections on specific ports:

```yaml
services:
  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"

  cache:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  wait-for-dependencies:
    image: drevops/docker-wait-for-dependencies:25.9.0
    depends_on:
      - database
      - cache
    command: database:5432 cache:6379
```

### Combined TCP and Health Check Commands

Wait for both TCP connectivity and custom health check endpoints:

```yaml
services:
  api:
    image: php:8.3-cli-alpine
    ports:
      - "8080:8080"
    command: php -S 0.0.0.0:8080 -t /app

  worker:
    image: alpine:3.18
    ports:
      - "9000:9000"
    command: nc -l -p 9000

  wait-for-dependencies:
    image: drevops/docker-wait-for-dependencies:25.9.0
    depends_on:
      - api
      - worker
    command:
      - api:8080
      - worker:9000
      - "curl -f http://api:8080/health"
      - "test -S /var/run/app.sock"
```

## Configuration

The container supports the following environment variables:

| Variable          | Default | Description                                                |
|-------------------|---------|------------------------------------------------------------|
| `SLEEP_LENGTH`    | `2`     | Time (in seconds) to wait between each check attempt       |
| `TIMEOUT_LENGTH`  | `300`   | Maximum time (in seconds) to wait before giving up         |
| `SUMMARY_ENABLED` | `true`  | Show summary message when all checks complete successfully |

## Development & Maintenance

```bash
npm run lint # Lint shell scripts and Dockerfile
npm run lint-fix # Auto-fix formatting issues
npm run test-unit # Run unit tests for validation logic
npm run test-functional # Run end-to-end tests with Docker
```

A new version is automatically published to Docker Hub when a new GitHub release
is created.

---
_This repository was created using the [Scaffold](https://getscaffold.dev/)
project template_
