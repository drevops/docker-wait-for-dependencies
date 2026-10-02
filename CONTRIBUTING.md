# Contributing

Thank you for considering a contribution to this project. This guide covers setting up a local environment, running the linting and tests, and how releases and dependency updates work.

## Local setup

You'll need Node.js, Docker, [ShellCheck](https://www.shellcheck.net/) and [shfmt](https://github.com/mvdan/sh) to lint and test, plus [kcov](https://github.com/SimonKagstrom/kcov) for code coverage. Install the test dependencies, including [Bats](https://github.com/bats-core/bats-core):

```bash
npm ci
```

## Linting and testing

```bash
npm run lint            # Lint shell scripts and Dockerfile
npm run lint-fix        # Auto-fix formatting issues
npm run test-unit       # Run unit tests
npm run test-coverage   # Run unit tests with code coverage
npm run test-functional # Run end-to-end tests with Docker
```

`npm run lint` runs hadolint in a container, and `npm run test-functional` builds the image and starts test stacks with Docker Compose, so both need Docker running. kcov doesn't report bash coverage reliably on macOS, so treat the coverage report from CI as the reference.

The `test` workflow runs the same linting and tests on every pull request to `main`.

## Releasing

Releases are scheduled to occur at a minimum of once per month.

Every push to `main` updates a draft release named after the current year and month, for example `26.10.0`. Publishing the release creates its tag, which builds the image for `linux/amd64` and `linux/arm64` and pushes it to Docker Hub as both the version tag and `latest`. Every push to `main` that passes the tests also pushes the `canary` image.

Versions follow [CalVer](https://calver.org/), as described in the [README](README.md#installation).

## Dependency updates

Renovate opens a pull request for each dependency update and merges it automatically once CI passes. The change then ships in the `canary` image.
