FROM oven/bun:1 AS webui-builder

WORKDIR /app

COPY nanobot/ /app/nanobot/

WORKDIR /app/nanobot/webui

RUN bun install && bun run build


FROM ghcr.io/astral-sh/uv:latest AS uv-builder


FROM python:3.12-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git gh bubblewrap openssh-client libmagic1 curl && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

COPY --from=uv-builder /uv /usr/local/bin/uv

RUN useradd -m -s /bin/bash -d /data nanobot

ENV HOME=/data

# Max seconds to wait between SSE stream chunks before treating an LLM stream
# as stalled. Applies to all streaming providers (Anthropic, OpenAI-compat,
# Bedrock, Codex). Default in code is 90s; raised to 300s here for slower models.
ENV NANOBOT_STREAM_IDLE_TIMEOUT_S=300

# HTTP request timeout (connect+read+write+pool) for the OpenAI-compatible and
# GitHub Copilot clients. Bounds each whole request to the model endpoint.
# Default in code is 120s; raised to 300s here.
ENV NANOBOT_OPENAI_COMPAT_TIMEOUT_S=300

# Outer wall-clock cap wrapping every non-streaming LLM call in the agent loop
# (a fallback if a provider client has no timeout of its own). Set to 0 to
# disable. Code default is 300s.
ENV NANOBOT_LLM_TIMEOUT_S=300

WORKDIR /app

COPY nanobot/ nanobot/
COPY --from=webui-builder /app/nanobot/nanobot/web/dist/ nanobot/nanobot/web/dist/

RUN NANOBOT_SKIP_WEBUI_BUILD=1 uv pip install --system --no-cache -e "nanobot"

RUN npm install -g @steipete/summarize && npm cache clean --force

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 18790 8765

USER nanobot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
