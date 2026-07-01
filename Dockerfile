FROM oven/bun:1 AS webui-builder

WORKDIR /app

COPY nanobot/ /app/nanobot/

WORKDIR /app/nanobot/webui

RUN bun install && bun run build


FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git bubblewrap openssh-client libmagic1 curl && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -d /data nanobot

ENV HOME=/data

WORKDIR /app

COPY nanobot/ nanobot/
COPY --from=webui-builder /app/nanobot/nanobot/web/dist/ nanobot/web/dist/

RUN NANOBOT_SKIP_WEBUI_BUILD=1 uv pip install --system --no-cache -e "nanobot"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Gateway health endpoint
EXPOSE 18790

# Opional WebUI/WebSocket channel ports
EXPOSE 8765

USER nanobot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
