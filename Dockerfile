FROM oven/bun:1 AS webui-builder

WORKDIR /app

COPY nanobot/ /app/nanobot/

WORKDIR /app/nanobot/webui

RUN bun install && bun run build


FROM ghcr.io/astral-sh/uv:latest AS uv-builder


FROM node:24-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git gh bubblewrap openssh-client libmagic1 curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=uv-builder /usr/local/bin/uv /usr/local/bin/uv

RUN uv python install 3.12

RUN useradd -m -s /bin/bash -d /data nanobot

ENV HOME=/data

WORKDIR /app

COPY nanobot/ nanobot/
COPY --from=webui-builder /app/nanobot/nanobot/web/dist/ nanobot/nanobot/web/dist/

RUN uv pip install --python 3.12 --system --no-cache -e "nanobot"

RUN npm install -g @steipete/summarize

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 18790 8765

USER nanobot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
