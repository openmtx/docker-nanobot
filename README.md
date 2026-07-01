# docker-nanobot

Docker packaging for [nanobot](https://github.com/HKUDS/nanobot) — an open-source, ultra-lightweight personal AI agent framework.

## Quick Start

To run nanobot as a container, copy the `docker-compose.yml` and create an empty `data/` directory:

```bash
mkdir -p data
```

### 1. Pull the image

```bash
docker compose pull
```

### 2. Onboard

This populates `data/.nanobot/` and creates a config file at `data/.nanobot/config.json`:

```bash
docker compose run --rm nanobot onboard
```

### 3. Configure a model

```bash
docker compose run --rm nanobot onboard --wizard
```

Choose **Quick Start**, sign up with a provider, and pick a model.  
For a local llama.cpp instance, choose **"Other OpenAI-compatible"** and fill in the endpoint.

> **Important**: Do not use `http://localhost:<port>/v1` as the endpoint — the container resolves `localhost` to itself, not your host. Use a real host address (e.g. `http://192.168.1.x:8080/v1` or `http://host.docker.internal:8080/v1`).

After the wizard, `data/.nanobot/config.json` will contain entries similar to:

```json
"model_presets": {
  "primary": {
    "label": "Primary",
    "model": "<model-name>",
    "provider": "custom",
    "maxTokens": 8192,
    "contextWindowTokens": 98304,
    "temperature": 0.1,
    "reasoningEffort": null
  }
},
"providers": {
  "custom": {
    "apiKey": "<your-api-key>",
    "apiBase": "http://<host-ip>:8000/v1",
    "apiType": "auto",
    "extraHeaders": null,
    "extraBody": null,
    "extraQuery": null,
    "proxy": null,
    "thinkingStyle": null
  }
}
```

### 4. Start the gateway

```bash
docker compose up -d
```

The WebUI is available at `http://localhost:8765`.

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

## Links

- **Official repo**: https://github.com/HKUDS/nanobot
- **Documentation**: https://nanobot.wiki
- **GitHub Container Registry**: `ghcr.io/openmtx/nanobot:latest`

## This Fork

Adds a [Mattermost](https://mattermost.com) channel integration (not yet merged upstream).
