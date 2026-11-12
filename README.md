# docker-nanobot

[![Build](https://github.com/openmtx/docker-nanobot/actions/workflows/build.yml/badge.svg)](https://github.com/openmtx/docker-nanobot/actions/workflows/build.yml)

Run your own AI agent with a browser interface using Docker. No Python, Node.js, or code setup needed.

## What you need

- **Docker** installed on your computer ([get Docker](https://docs.docker.com/get-docker/))
- A terminal (Command Prompt, PowerShell, or Terminal)

## Setup

Create a folder for nanobot and copy these two files into it:

- [`docker-compose.yml`](https://raw.githubusercontent.com/openmtx/docker-nanobot/master/docker-compose.yml)
- Create an empty folder named `data`

Then open a terminal in that folder and follow the steps below.

### Step 1: Download the image

```bash
docker compose pull
```

### Step 2: Create a config file

```bash
docker compose run --rm nanobot onboard
```

This creates the folder `data/.nanobot/` with a file called `config.json` inside — that's where your settings live.

### Step 3: Tell nanobot which AI model to use

```bash
docker compose run --rm nanobot onboard --wizard
```

A menu will appear. Choose **Quick Start**, then sign up with a provider (like OpenAI or Google) and pick a model.

**Running a local model** (like llama.cpp on your computer)?
Choose **"Other OpenAI-compatible"** instead, and enter your server address.

> ⚠️ Don't use `http://localhost:...` — inside the container, "localhost" points to the container itself, not your computer. Use your computer's actual IP address instead (e.g. `http://192.168.1.5:8000/v1`), or try `http://host.docker.internal:8000/v1`. On Linux, `host.docker.internal` does not resolve automatically — uncomment the `extra_hosts` section in `docker-compose.yml` to enable it.

### Step 4: Start nanobot

```bash
docker compose up -d
```

### Step 5: Open the WebUI

Open your browser and go to [http://localhost:8765](http://localhost:8765).

That's it. You can now chat with your AI agent.

## How to stop

```bash
docker compose down
```

## What's inside

- A WebUI to chat with your agent (at port 8765)
- Support for chat apps: Telegram, Discord, Slack, Mattermost, WeChat, Email, and more
- A health-check endpoint at port 18790
- All your data saved in the `data/` folder

## Upgrading from 0.3.0

This image ships nanobot **0.3.5**, which includes breaking config changes.

1. **Back up `data/` and stop the old container first.** Sessions moved from
   `<workspace>/sessions/` to `<config-dir>/sessions/<workspace-id>/` and are
   auto-migrated on first start (legacy files are deleted after a verified copy).
   Never run the 0.3.0 and 0.3.5 containers against the same `data/` folder.
2. **Email:** `verifySpf`/`verifyDkim` now require `trustedAuthservIds` (the
   receiver's exact `authserv-id`), otherwise the channel will not start.
3. **Dream:** `agents.defaults.dream.modelOverride` must name a key from
   `modelPresets`, not a raw model ID.
4. **Defaults changed:** `channels.sendToolHints` is now `true`,
   `agents.defaults.maxConcurrentSubagents` is `4`, and an omitted timezone is
   auto-detected (UTC in this container unless `TZ` is set).
   `NANOBOT_LLM_TIMEOUT_S` is no longer read, and
   `NANOBOT_MAX_CONCURRENT_REQUESTS` is unlimited when unset; this Compose file
   pins it to `3` to match 0.3.0.
5. **Channels:** chat SDKs are no longer bundled. Bake the ones you need at build
   time so they survive container recreation:

   ```bash
   NANOBOT_CHANNELS=telegram,slack docker compose build
   ```

   `nanobot plugins enable <channel>` also installs into the image's virtualenv
   and is handy for trying a channel in a one-off `docker compose run`, but that
   install lives in the container's writable layer and is lost when it is
   removed.

6. **Terminal:** Bun is bundled, so interactive `agent` opens the native TUI;
   `--classic` keeps the legacy prompt. Both need an interactive terminal, while
   `-m` runs one-shot:

   ```bash
   docker compose run --rm nanobot agent -m "Hello!"
   docker compose run --rm -it nanobot agent
   docker compose run --rm -it nanobot agent --classic
   ```

After upgrading, run `docker compose run --rm nanobot status` and review the
gateway logs for config or migration warnings.

To roll back to 0.3.0, stop the container and copy sessions back to the
workspace first:

```bash
docker compose run --rm nanobot sessions restore-workspace \
  --workspace /data/.nanobot/workspace
```

## Links

- **Official nanobot repo**: https://github.com/HKUDS/nanobot
- **Documentation**: https://nanobot.wiki
- **Pre-built image**: `ghcr.io/openmtx/nanobot:latest`

## About this image

This image is built from a fork at https://github.com/goodtiding5/nanobot, which adds [Mattermost](https://mattermost.com) support (not yet merged upstream).
