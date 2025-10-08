# hadolint global ignore=DL3018
FROM alpine:3.22.2@sha256:265b17e252b9ba4c7b7cf5d5d1042ed537edf6bf16b66130d93864509ca5277f

LABEL org.opencontainers.image.authors="Alex Skrypnyk <alex@drevops.com>" maintainer="Alex Skrypnyk <alex@drevops.com>"

RUN apk add --no-cache bash curl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
