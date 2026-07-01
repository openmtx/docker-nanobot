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

> ⚠️ Don't use `http://localhost:...` — inside the container, "localhost" points to the container itself, not your computer. Use your computer's actual IP address instead (e.g. `http://192.168.1.5:8000/v1`), or try `http://host.docker.internal:8000/v1` (works on Docker Desktop).

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

## Links

- **Official nanobot repo**: https://github.com/HKUDS/nanobot
- **Documentation**: https://nanobot.wiki
- **Pre-built image**: `ghcr.io/openmtx/nanobot:latest`

## About this image

This image is built from a fork at https://github.com/openmtx/nanobot, which adds [Mattermost](https://mattermost.com) support (not yet merged upstream).
