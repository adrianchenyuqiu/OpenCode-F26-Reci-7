FROM oven/bun:1.3.14-debian AS build

WORKDIR /app

# The build context excludes .git; set the channel and version explicitly.
ENV HUSKY=0 \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    OPENCODE_CHANNEL=recitation \
    OPENCODE_VERSION=1.18.31-reci

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates git build-essential python3 pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY . .
RUN bun install --frozen-lockfile

# Embed this checkout's web UI instead of proxying to app.opencode.ai.
RUN bun run --cwd packages/opencode build --single --skip-install \
    && mkdir -p /out \
    && cp packages/opencode/dist/opencode-linux-*/bin/opencode /out/opencode

FROM debian:trixie-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates libgcc-s1 libstdc++6 ripgrep git bash curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/opencode /usr/local/bin/opencode
RUN /usr/local/bin/opencode --version

ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=0 \
    OPENCODE_DISABLE_AUTOUPDATE=1

WORKDIR /workspace
EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:4096/global/health || exit 1

CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]
