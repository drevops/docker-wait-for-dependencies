# hadolint global ignore=DL3018
FROM alpine:3.24.3@sha256:1b7232cda4ca3dc20b5d1247bdc9bfb631f2661d15d323bdd6fccc035ed1a9e7

LABEL org.opencontainers.image.authors="Alex Skrypnyk <alex@drevops.com>" \
      org.opencontainers.image.source="https://github.com/drevops/docker-wait-for-dependencies"

RUN apk add --no-cache bash curl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
