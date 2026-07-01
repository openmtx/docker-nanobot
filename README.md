# docker-nanobot

Docker packaging for [nanobot](https://github.com/HKUDS/nanobot) — an open-source, ultra-lightweight personal AI agent framework.

## Quick Start

```bash
docker compose up -d
```

This starts the gateway on port `8765` with the WebUI and WebSocket channel access. Data persists in `./data/`.

## Features

- Bundles nanobot, its WebUI, and all dependencies in a single image
- WebUI available at `http://localhost:8765` after starting the gateway
- Multi-channel support: Telegram, Discord, Slack, Mattermost, WeChat, Email, and more
- Pre-configured healthcheck on port `18790`
- Data volume mounted at `/data` for configuration and persistence

## Building

```bash
docker build -t ghcr.io/openmtx/nanobot:latest .
```

The WebUI is built with Bun inside the Dockerfile — no host tooling required.

## Configuration

Place your `config.json` at `./data/config.json`. See the [official docs](https://nanobot.wiki) for all available options.

## Links

- **Official repo**: https://github.com/HKUDS/nanobot
- **Documentation**: https://nanobot.wiki
- **GitHub Container Registry**: `ghcr.io/openmtx/nanobot:latest`

## This Fork

Adds a [Mattermost](https://mattermost.com) channel integration (not yet merged upstream).
