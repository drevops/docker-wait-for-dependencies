# hadolint global ignore=DL3018
FROM alpine:3.24.3@sha256:b3413572228e34bd1c9245f5565e6cd127005655e8a7899aef33d8e83255c9e6

LABEL org.opencontainers.image.authors="Alex Skrypnyk <alex@drevops.com>" \
      org.opencontainers.image.source="https://github.com/drevops/docker-wait-for-dependencies"

RUN apk add --no-cache bash curl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
