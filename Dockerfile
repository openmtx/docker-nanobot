FROM ghcr.io/astral-sh/uv:latest AS uv-builder


FROM node:24-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git gh bubblewrap openssh-client libmagic1 curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=uv-builder /uv /usr/local/bin/uv

RUN uv python install 3.12

RUN useradd -m -s /bin/bash -d /data nanobot

ENV HOME=/data

WORKDIR /app

COPY nanobot/ nanobot/

WORKDIR /app/nanobot/webui
RUN npm install && npm run build

WORKDIR /app
RUN NANOBOT_SKIP_WEBUI_BUILD=1 uv venv --python 3.12 /app/.venv && \
    uv pip install --python /app/.venv/bin/python3 --no-cache -e "nanobot"

ENV PATH="/app/.venv/bin:$PATH"

RUN npm install -g @steipete/summarize

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 18790 8765

USER nanobot

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
