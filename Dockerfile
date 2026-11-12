FROM oven/bun:1.3.13 AS webui-builder

WORKDIR /app

COPY nanobot/ /app/nanobot/

WORKDIR /app/nanobot/webui

RUN bun install --frozen-lockfile && bun run build


FROM ghcr.io/astral-sh/uv:latest AS uv-builder


FROM python:3.12-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git gh bubblewrap openssh-client libmagic1 curl && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

COPY --from=uv-builder /uv /usr/local/bin/uv

# Bun powers the native terminal UI (and is the WebUI build tool upstream).
# Pin the runtime nanobot's TUI launcher expects (nanobot/bun.py), not the
# moving `oven/bun:1` tag.
COPY --from=webui-builder /usr/local/bin/bun /usr/local/bin/bun
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx

RUN useradd -m -s /bin/bash -d /data nanobot

ENV HOME=/data
# Prepare the default config for published container ports. Set to 0 to manage
# config.json entirely by hand.
ENV NANOBOT_DOCKER_BOOTSTRAP=1

# Install into a virtualenv owned by the runtime user so `nanobot plugins
# enable <channel>` can add channel dependencies without root.
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

RUN uv venv --seed "$VIRTUAL_ENV"

# Max seconds to wait between SSE stream chunks before treating an LLM stream
# as stalled. Applies to all streaming providers (Anthropic, OpenAI-compat,
# Bedrock, Codex). Default in code is 90s; raised to 300s here for slower models.
ENV NANOBOT_STREAM_IDLE_TIMEOUT_S=300

# HTTP request timeout (connect+read+write+pool) for the OpenAI-compatible and
# GitHub Copilot clients. Bounds each whole request to the model endpoint.
# Default in code is 120s; raised to 300s here.
ENV NANOBOT_OPENAI_COMPAT_TIMEOUT_S=300

WORKDIR /app

COPY nanobot/ nanobot/
COPY --from=webui-builder /app/nanobot/nanobot/web/dist/ nanobot/nanobot/web/dist/

# Bake selected channel SDKs into the image (comma-separated, e.g.
# `--build-arg NANOBOT_CHANNELS=telegram,slack`).
ARG NANOBOT_CHANNELS=

RUN NANOBOT_SKIP_WEBUI_BUILD=1 uv pip install --python "$VIRTUAL_ENV/bin/python" --no-cache "./nanobot[mst]" && \
    if [ -n "$NANOBOT_CHANNELS" ]; then \
        cd nanobot && \
        PIP_NO_CACHE_DIR=1 python -m scripts.install_channel_dependencies \
            $(printf '%s' "$NANOBOT_CHANNELS" | tr ',' ' ') || exit 1; \
    fi && \
    chown -R nanobot:nanobot "$VIRTUAL_ENV"

# Pre-install the native TUI dependencies so `nanobot agent` starts without a
# network fetch, and keep the checkout writable for its launcher. The installed
# package cannot discover this source checkout on its own, so the launcher is
# pointed at a wrapper that runs it with the bundled Bun runtime.
RUN cd nanobot/tui && bun install --frozen-lockfile && \
    chown -R nanobot:nanobot /app/nanobot/tui
COPY tui-wrapper.sh /usr/local/bin/nanobot-tui
RUN chmod +x /usr/local/bin/nanobot-tui
ENV NANOBOT_TUI_BIN=/usr/local/bin/nanobot-tui

RUN npm install -g @steipete/summarize && npm cache clean --force

COPY entrypoint.sh docker-config.py /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/docker-config.py

EXPOSE 18790 8765

USER nanobot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gateway"]
