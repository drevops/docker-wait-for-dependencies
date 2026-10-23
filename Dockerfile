# hadolint global ignore=DL3018
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

LABEL org.opencontainers.image.authors="Alex Skrypnyk <alex@drevops.com>" \
      org.opencontainers.image.source="https://github.com/drevops/docker-wait-for-dependencies"

RUN apk add --no-cache bash curl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
