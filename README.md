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

On first start, the logs print the WebUI password (or use the
`NANOBOT_WEB_TOKEN` value you supplied):

```bash
docker compose logs nanobot | grep -i "WebUI password"
```

### Step 5: Open the WebUI

Open your browser and go to [http://localhost:8765](http://localhost:8765),
then enter the WebUI password when prompted.

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

## Upgrading from 0.3.5 (or older)

This image now ships the nanobot release pinned by the `nanobot` submodule
(`nanobot/pyproject.toml`), currently **0.4.1**. Stop the old container and back
up the complete `data/` folder before starting the new image.

1. **Sessions move to SQLite and are one-way.** On first start, JSONL history is
   imported into `<config-dir>/sessions/<workspace-id>/sessions.sqlite3`; the
   source files are retained under `jsonl-backup/`. Keep the old
   `<config-dir>/webui/` directory too: it holds saved preferences and the
   legacy history backups. 0.4.x is the last release line that imports legacy
   JSONL, so installations with only JSONL data must upgrade through 0.4.x
   before using 0.5.0. The old `sessions restore-workspace` command has been
   removed: rolling back now requires restoring a complete pre-upgrade backup.
   Never run 0.3.5 and 0.4.0 against the same `data/` folder at the same time.

2. **WebUI bind and password are fixed automatically.** 0.3.5 configs bind to
   `127.0.0.1`, which Docker port publishing cannot reach. With
   `NANOBOT_DOCKER_BOOTSTRAP=1` (set in this Compose file), startup changes only
   loopback/missing `channels.websocket.host` values to `0.0.0.0`, adds a
   `tokenIssueSecret` when no WebUI auth exists, and writes
   `config.json.pre-0.4.0.bak` first. The generated password is printed in the
   logs. Set `NANOBOT_WEB_TOKEN` to choose it yourself. To manage config
   manually, set `NANOBOT_DOCKER_BOOTSTRAP=0` and configure `host: "0.0.0.0"`
   plus `tokenIssueSecret` (or `token`) yourself.

3. **Configuration migrations.** Review the gateway logs after the first start:

   - **Proxy:** one legacy per-feature proxy address migrates to `network.proxy`
     and affected features get `useProxy: true`. Configs with several different
     proxy addresses must choose one before upgrading, otherwise startup fails.
   - **OpenAI API selector:** `providers.openai.apiType` / `api_type` is
     migrated to the new `api` setting. Saving with 0.4.0 completes the
     migration; the old field is accepted only through the next release.
   - **Shell timeout:** `tools.exec.timeout` is still a hard-runtime alias, so
     explicit values are preserved, but the new default is `3600` seconds
     (previously `60`). New `idleTimeout`/`idleAction` settings now control
     inactivity separately.
   - **Concurrency:** `NANOBOT_MAX_CONCURRENT_REQUESTS` remains unlimited when
     unset; this Compose file pins it to `3`. `NANOBOT_LLM_TIMEOUT_S` is no
     longer read.
   - **Coming from 0.3.0:** email `verifySpf`/`verifyDkim` also require
     `trustedAuthservIds`, and `agents.defaults.dream.modelOverride` must name
     a key from `modelPresets` rather than a raw model ID.

4. **Channels:** chat SDKs are not bundled. Bake the ones you need at build time
   so they survive container recreation:

   ```bash
   NANOBOT_CHANNELS=telegram,slack docker compose build
   ```

   `nanobot plugins enable <channel>` also installs into the image's virtualenv
   and is handy for trying a channel in a one-off `docker compose run`, but that
   install lives in the container's writable layer and is lost when it is
   removed.

5. **Do not use the in-app updater in this container.** The 0.4.0 WebUI updater
   targets installer/uv environments, not container images. Rebuild or pull the
   image and recreate the service with the same `data/` volume. The obsolete
   `update-setup` workspace skill is no longer bundled; do not replay upgrade
   commands saved by it.

6. **Terminal:** Bun and the matching TUI source are bundled, so interactive
   `agent` opens the native TUI without downloading a release archive;
   `--classic` keeps the legacy prompt. Both need an interactive terminal, while
   `-m` runs one-shot:

   ```bash
   docker compose run --rm nanobot agent -m "Hello!"
   docker compose run --rm -it nanobot agent
   docker compose run --rm -it nanobot agent --classic
   ```

After upgrading, run `docker compose run --rm nanobot status`, confirm the
running version in the WebUI, open an older conversation, and send a new
message. Check the gateway logs for config, migration, or channel warnings. Keep
the pre-upgrade backup until this verification succeeds.

## Links

- **Official nanobot repo**: https://github.com/HKUDS/nanobot
- **Documentation**: https://nanobot.wiki
- **Pre-built image**: `ghcr.io/openmtx/nanobot:latest`

## About this image

This image is built from a fork at https://github.com/goodtiding5/nanobot, which adds [Mattermost](https://mattermost.com) support (not yet merged upstream).
