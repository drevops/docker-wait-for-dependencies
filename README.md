<p align="center">
  <a href="" rel="noopener">
  <img width=150px height=150px src="logo.png" alt="Wait for dependencies logo"></a>
</p>

<h1 align="center">Docker wait for dependencies</h1>

<div align="center">

[![GitHub Issues](https://img.shields.io/github/issues/drevops/docker-wait-for-dependencies.svg)](https://github.com/drevops/docker-wait-for-dependencies/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/drevops/docker-wait-for-dependencies.svg)](https://github.com/drevops/docker-wait-for-dependencies/pulls)
[![Test](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml/badge.svg)](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/drevops/docker-wait-for-dependencies/graph/badge.svg?token=BZK6852630)](https://codecov.io/gh/drevops/docker-wait-for-dependencies)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/drevops/docker-wait-for-dependencies)
![LICENSE](https://img.shields.io/github/license/drevops/docker-wait-for-dependencies)
![Renovate](https://img.shields.io/badge/renovate-enabled-green?logo=renovatebot)

[![Docker Pulls](https://img.shields.io/docker/pulls/drevops/docker-wait-for-dependencies?logo=docker)](https://hub.docker.com/r/drevops/docker-wait-for-dependencies)
![amd64](https://img.shields.io/badge/arch-linux%2Famd64-brightgreen)
![arm64](https://img.shields.io/badge/arch-linux%2Farm64-brightgreen)

[![Vortex Ecosystem](https://img.shields.io/badge/%F0%9F%8C%80-Vortex%20Ecosystem-2C5A68?style=for-the-badge&labelColor=65ACBC)](https://github.com/drevops/vortex)
</div>

---

<p align="center">
  Container to wait for services to be ready before proceeding with the stack start
  <br>
  Available for <code>linux/amd64</code> and <code>linux/arm64</code> architectures.
  <br>
</p>

## Features

- **TCP connectivity**: Wait for services to be accessible via TCP (using `host:port` format)
- **Shell command**: Execute arbitrary shell commands and wait for successful completion
- **Configurable timeouts**: Customizable sleep intervals and timeout periods
- **Hung check protection**: A check that's still running at the timeout is stopped, so it can't keep the stack waiting
- **User-friendly output**: Clear progress indicators and status messages
- **Multi-architecture support**: Available for `linux/amd64` and `linux/arm64`

## Installation

The image is published on [Docker Hub](https://hub.docker.com/r/drevops/docker-wait-for-dependencies), so there's nothing to install: reference it from a Compose file, as shown in [Usage](#usage).

| Tag          | Points to                                         |
|--------------|---------------------------------------------------|
| `YY.M.patch` | A specific release, for example `26.10.0`         |
| `latest`     | The most recent release                           |
| `canary`     | The latest commit on `main` that passed the tests |

Releases follow [CalVer](https://calver.org/): `YY` is the last 2 digits of the year, `M` is the month without a leading zero, and `patch` is the patch number within the month, starting at `0`. For example, `25.4.2` is the third patch in April 2025.

## Usage

Pass 1 or more targets as the container's command. The container checks them in order and only moves on to the next target once the current one is ready:

- A `host:port` target is ready once the port accepts TCP connections, checked with `nc -z`.
- Any other target runs as a shell command with `bash -c` and is ready once the command exits with `0`.

A target counts as `host:port` only when it has exactly 1 colon, a host made of letters, digits, `.`, `_` and `-`, and a port from `1` to `65535`. Anything else runs as a shell command, so a bare URL such as `http://api:8080/health` never succeeds: wrap it in `curl -f` instead.

Shell commands run inside the wait-for-dependencies container, not in the service they check. The image is Alpine Linux with `bash` and `curl` added, so commands can use those as well as BusyBox tools such as `nc` and `wget`. The container discards a command's own output, so the logs show only the container's status lines, plus the `set -x` trace when `DEBUG` is `1`.

### TCP connectivity

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

  app:
    image: alpine:3.22
    depends_on:
      # Will start only after the wait-for-dependencies finishes waiting
      # for both database and cache to be reachable.
      wait-for-dependencies:
        condition: service_completed_successfully
    ports:
      - "8000:8000"

  wait-for-dependencies:
    image: drevops/docker-wait-for-dependencies:26.10.0
    depends_on:
      - database
      - cache
    command: database:5432 cache:6379
```

### Combined TCP and health check commands

Wait for both TCP connectivity and custom health check endpoints:

```yaml
services:
  api:
    image: php:8.4-cli-alpine
    ports:
      - "8080:8080"
    command: php -S 0.0.0.0:8080 -t /app

  worker:
    image: alpine:3.22
    ports:
      - "9000:9000"
    command: nc -l -p 9000

  app:
    image: alpine:3.22
    depends_on:
      # Will start only after the wait-for-dependencies finishes waiting
      # for both api and worker to be reachable.
      wait-for-dependencies:
        condition: service_completed_successfully
    ports:
      - "8000:8000"

  wait-for-dependencies:
    image: drevops/docker-wait-for-dependencies:26.10.0
    depends_on:
      - api
      - worker
    command:
      - api:8080
      - worker:9000
      - "curl -f http://api:8080/health"
```

### Output and exit codes

The container prints a line when it starts and finishes each target, plus a notice at most once every 10 seconds while it's still waiting:

```text
Waiting (tcp): database:5432 …
… still waiting (tcp): database:5432 (elapsed 10s, timeout 300s)
✓ Ready (tcp): database:5432
Waiting (tcp): cache:6379 …
✓ Ready (tcp): cache:6379
☑ All services have started.
```

It exits with `0` once every target is ready, which is what `condition: service_completed_successfully` waits for. It exits with `1` as soon as a target times out, without checking the targets after it, and with `2` when it starts without any targets.

## Configuration

The container supports the following environment variables:

| Variable          | Default | Description                                                           |
|-------------------|---------|-----------------------------------------------------------------------|
| `SLEEP_LENGTH`    | `2`     | Time (in seconds) to wait between each check attempt                  |
| `TIMEOUT_LENGTH`  | `300`   | Time (in seconds) to wait for each target before giving up            |
| `SUMMARY_ENABLED` | `true`  | Show a summary message once every target is ready, when set to `true` |
| `DEBUG`           | unset   | Trace each command as it runs (`set -x`) when set to `1`              |

The container stops a check that's still running when `TIMEOUT_LENGTH` runs out, so a hung `curl` can't keep your stack waiting. It sends `SIGKILL` to the check's process group, which holds the check and every process it starts. Nothing in the group can ignore or trap that signal, so a stopped check never counts as ready. If one of your checks legitimately needs more time, raise `TIMEOUT_LENGTH`.

The attempt after the last sleep always gets at least 1 second, so a target can run past `TIMEOUT_LENGTH` by up to `SLEEP_LENGTH` plus 1 second. The container also stops anything a finished check left running in its process group. A process that detaches into its own session, for example with `setsid`, leaves the group and keeps running.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for local development setup, the linting and testing commands, and how releases are made.

---
_This repository was created using the [Scaffold](https://getscaffold.dev/) project template_
