# syntax=docker/dockerfile:latest

# General base layer
FROM --platform=$BUILDPLATFORM golang:alpine AS base
ARG TARGETOS TARGETARCH
ENV GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0
## Shared Go cache
ENV GOMODCACHE=/go/pkg/mod GOCACHE=/root/.cache/go-build
RUN apk add --no-cache ca-certificates git tzdata jq && \
  update-ca-certificates && \
  adduser -D -u 65532 -h /home/nonroot -s /sbin/nologin nonroot

# envwarp - Get
FROM base AS envwarp-src
ARG SRC_REPO=Lanrenbang/envwarp
ARG SRC_RELEASE=https://api.github.com/repos/${SRC_REPO}/releases/latest \
    SRC_GIT=https://github.com/${SRC_REPO}.git
WORKDIR /src
ADD ${SRC_RELEASE} /tmp/latest-release.json
RUN --mount=type=cache,id=gitcache,target=/root/.cache/git \
    set -eux; \
    SRC_TAG=$(jq -r '.tag_name' /tmp/latest-release.json); \
    if [ -z "$SRC_TAG" ] || [ "$SRC_TAG" = "null" ]; then \
      echo "Error: Failed to get tag_name from GitHub API." >&2; \
      exit 1; \
    fi; \
    echo "Fetching tag: $SRC_TAG"; \
    git init .; \
    git remote add origin "$SRC_GIT"; \
    git fetch --depth=1 origin "$SRC_TAG"; \
    git checkout --detach FETCH_HEAD; \
    if git describe --tags --always 2>/dev/null | grep -qv '^[0-9a-f]\{7\}$'; then \
      echo "Tags found, skipping fetch"; \
    else \
      echo "Fetching full history for tags..."; \
      git fetch --unshallow || true; \
      git fetch --tags --force; \
    fi

# envwarp - Build
FROM base AS envwarp-build
WORKDIR /src
COPY --from=envwarp-src /src/ .
RUN --mount=type=cache,id=gomodcache,target=/go/pkg/mod \
    --mount=type=cache,id=gobuildcache,target=/root/.cache/go-build \
    go build -o /out/envwarp -trimpath -tags=osusergo,netgo -buildvcs=false \
      -ldflags "-X main.version=$(git describe --tags --always --dirty | cut -c2-) -s -w -buildid=" .


# xray - Get
FROM base AS xray-src
ARG SRC_REPO=XTLS/Xray-core
ARG SRC_RELEASE=https://api.github.com/repos/${SRC_REPO}/releases/latest \
    SRC_GIT=https://github.com/${SRC_REPO}.git
WORKDIR /src
ADD ${SRC_RELEASE} /tmp/latest-release.json
RUN --mount=type=cache,id=gitcache,target=/root/.cache/git \
    set -eux; \
    SRC_TAG=$(jq -r '.tag_name' /tmp/latest-release.json); \
    if [ -z "$SRC_TAG" ] || [ "$SRC_TAG" = "null" ]; then \
      echo "Error: Failed to get tag_name from GitHub API." >&2; \
      exit 1; \
    fi; \
    echo "Fetching tag: $SRC_TAG"; \
    git init .; \
    git remote add origin "$SRC_GIT"; \
    git fetch --depth=1 origin "$SRC_TAG"; \
    git checkout --detach FETCH_HEAD; \
    if git describe --tags --always 2>/dev/null | grep -qv '^[0-9a-f]\{7\}$'; then \
      echo "Tags found, skipping fetch"; \
    else \
      echo "Fetching full history for tags..."; \
      git fetch --unshallow || true; \
      git fetch --tags --force; \
    fi

# xray - Build
FROM base AS xray-build
WORKDIR /src
COPY --from=xray-src /src/ .
RUN --mount=type=cache,id=gomodcache,target=/go/pkg/mod \
    --mount=type=cache,id=gobuildcache,target=/root/.cache/go-build \
    go build -o /out/xray -trimpath -tags=osusergo,netgo -buildvcs=false \
      -ldflags "-X github.com/xtls/xray-core/core.build=$(git describe --tags --always --dirty | cut -c2-) -s -w -buildid=" ./main


# tmp-data
FROM base AS tmp-data
# Download geodat into a staging directory
ADD https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat /tmp/geo/xray/geoip.dat
ADD https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat /tmp/geo/xray/geosite.dat

RUN mkdir -p /tmp/etc/templates /tmp/etc/xray /tmp/log/xray


# Build finally image
FROM scratch

LABEL org.opencontainers.image.title="xray-services" \
      org.opencontainers.image.authors="bobbynona" \
      org.opencontainers.image.vendor="L.R.B" \
      org.opencontainers.image.source="https://github.com/Lanrenbang/xray-services" \
      org.opencontainers.image.url="https://github.com/Lanrenbang/xray-services"

COPY --from=base /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
COPY --from=base /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=envwarp-build --chown=0:0 --chmod=755 /out/envwarp /usr/local/bin/envwarp
COPY --from=xray-build --chown=0:0 --chmod=755 /out/xray /usr/local/bin/xray

COPY --from=tmp-data --chown=0:0 --chmod=755 /tmp/geo /usr/local/share/
COPY --from=tmp-data --chown=65532:65532 --chmod=0775 /tmp/etc /usr/local/etc/
COPY --from=tmp-data --chown=65532:65532 --chmod=0775 /tmp/log /var/

VOLUME /usr/local/etc/templates
VOLUME /var/log/xray

ARG TZ=Etc/UTC
ENV TZ=$TZ

ENTRYPOINT [ "/usr/local/bin/envwarp" ]
