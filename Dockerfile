# gitlab-cleaner: the `gitlab-cleaner` script plus a current `glab`, in a small Alpine image.
#
# glab comes from the official image instead of Alpine's package, which lags behind.
FROM gitlab/glab:v1.130.0 AS glab

FROM alpine:3.24

ARG BUILD_DATE
ARG APP_VERSION=dev

LABEL org.opencontainers.image.authors='Martin Reinhardt (martin@m13t.de)' \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.version=$APP_VERSION \
    org.opencontainers.image.title='gitlab-cleaner' \
    org.opencontainers.image.description='Deletes stale branches across all GitLab projects a token can access' \
    org.opencontainers.image.url='https://hub.docker.com/r/m13t/gitlab-cleaner' \
    org.opencontainers.image.documentation='https://github.com/m13tLabs/gitlab-cleaner' \
    org.opencontainers.image.source='https://github.com/m13tLabs/gitlab-cleaner.git' \
    org.opencontainers.image.licenses='MIT'

# hadolint ignore=DL3018
RUN apk add --no-cache bash ca-certificates jq \
 && adduser -D -u 1000 cleaner

COPY --from=glab /usr/bin/glab /usr/bin/glab
COPY --chmod=755 gitlab-cleaner /usr/bin/gitlab-cleaner

# glab writes its config below HOME; keep it writable for any runtime UID.
ENV HOME=/tmp \
    GITLAB_CLEANER_VERSION=$APP_VERSION \
    GLAB_SEND_TELEMETRY=false \
    GLAB_NO_PROMPT=true

USER 1000:1000
WORKDIR /tmp

ENTRYPOINT ["gitlab-cleaner"]
CMD ["--help"]
