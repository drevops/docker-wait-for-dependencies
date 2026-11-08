# hadolint global ignore=DL3018
FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

LABEL org.opencontainers.image.authors="Alex Skrypnyk <alex@drevops.com>" \
      org.opencontainers.image.source="https://github.com/drevops/docker-wait-for-dependencies"

RUN apk add --no-cache bash curl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
