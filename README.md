<p align="center">
  <a href="" rel="noopener">
  <img width=150px height=150px src="logo.png" alt="Wait for dependencies logo"></a>
</p>

<h1 align="center">Docker wait for dependencies</h1>

<div align="center">

[![GitHub Issues](https://img.shields.io/github/issues/DrevOps/docker-wait-for-dependencies.svg)](https://github.com/DrevOps/docker-wait-for-dependencies/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/DrevOps/docker-wait-for-dependencies.svg)](https://github.com/DrevOps/docker-wait-for-dependencies/pulls)
[![Test](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml/badge.svg)](https://github.com/drevops/docker-wait-for-dependencies/actions/workflows/test.yml)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/DrevOps/docker-wait-for-dependencies)
![LICENSE](https://img.shields.io/github/license/DrevOps/docker-wait-for-dependencies)
![Renovate](https://img.shields.io/badge/renovate-enabled-green?logo=renovatebot)

[![Docker Pulls](https://img.shields.io/docker/pulls/drevops/docker-wait-for-dependencies?logo=docker)](https://hub.docker.com/r/drevops/docker-wait-for-dependencies)
![amd64](https://img.shields.io/badge/arch-linux%2Famd64-brightgreen)
![arm64](https://img.shields.io/badge/arch-linux%2Farm64-brightgreen)

</div>

---

<p align="center">
  A simple container that puts itself on hold until the other services declared in the <code>docker-compose.yml</code> are accessible via TCP.
  <br>
  Available for <code>linux/amd64</code> and <code>linux/arm64</code> architectures.
  <br>
</p>

## Example usage:

Sample `docker-compose.yml`:

```yaml
version: '2'
services:
  mongo:
    image: mongo:6
    container_name: mongo
    ports:
      - 27017:27017
    networks:
      - my-network

  redis:
    container_name: redis
    image: redis:6
    ports:
      - 6379:6379
    networks:
      - my-network

  server:
    container_name: server
    image: server
    ports:
      - 3000:3000
    networks:
      - my-network

  start_dependencies:
    image: drevops/docker-wait-for-dependencies:23.12.0
    depends_on:
      - mongo
      - redis
    container_name: wait-for-dependencies
    command: mongo:27017 redis:6379
    networks:
      - my-network
```

Then, to guarantee that `mongo` and `redis` are ready before running `server`:

```bash
$ docker-compose run --rm start_dependencies
# Some output from docker compose
$ docker-compose up server
```

By default, there will be a 2 second sleep time between each check. You can modify this by setting the `SLEEP_LENGTH` environment variable:

```yaml
  start_dependencies:
    image: drevops/docker-wait-for-dependencies:23.12.0
    environment:
      - SLEEP_LENGTH: 0.5
```

By default, there will be a 300 seconds timeout before cancelling the wait_for. You can modify this by setting the `TIMEOUT_LENGTH` environment variable:

```yaml
  start_dependencies:
    image: drevops/docker-wait-for-dependencies:23.12.0
    environment:
      - SLEEP_LENGTH: 1
      - TIMEOUT_LENGTH: 60
```

## Acknowledgments

The main functionality is based on
the [docker-wait-for-dependencies](https://github.com/ducktors/docker-wait-for-dependencies) project.
A special thank you to the contributors for their original work.

---
_This repository was created using the [Scaffold](https://getscaffold.dev/) project template_
