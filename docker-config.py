#!/usr/bin/env python3
"""Initialize or adapt the default config for a Docker deployment.

A fresh config needs container-friendly bind addresses and a WebUI password.
Configs written by the 0.3.x image also used loopback-only binds, which Docker
port publishing cannot reach, so upgrade them in place (after taking a backup).

Run with NANOBOT_DOCKER_BOOTSTRAP=0 to leave an existing config untouched.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
from pathlib import Path

from nanobot.cli.docker_bootstrap import initialize_config

_LOOPBACK_HOSTS = {"", "127.0.0.1", "localhost", "::1"}
_WILDCARD_HOSTS = {"0.0.0.0", "::"}


def _load(path: Path) -> tuple[str, dict[str, object]] | None:
    try:
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        print(f"[entrypoint] warning: cannot read {path}: {exc}", file=sys.stderr)
        return None
    if not isinstance(data, dict):
        print(f"[entrypoint] warning: {path} is not a JSON object", file=sys.stderr)
        return None
    return raw, data


def _mapping(parent: dict[str, object], key: str) -> dict[str, object] | None:
    value = parent.get(key)
    if value is None:
        value = {}
        parent[key] = value
    return value if isinstance(value, dict) else None


def _update(path: Path) -> None:
    loaded = _load(path)
    if loaded is None:
        return
    raw, data = loaded
    channels = _mapping(data, "channels")
    if channels is None:
        print(f"[entrypoint] warning: {path} has a non-object channels setting", file=sys.stderr)
        return
    websocket = _mapping(channels, "websocket")
    if websocket is None:
        print(f"[entrypoint] warning: {path} has a non-object websocket setting", file=sys.stderr)
        return
    if websocket.get("enabled") is False:
        return

    changed = False
    host = websocket.get("host")
    if not isinstance(host, str) or host.strip().lower() in _LOOPBACK_HOSTS:
        websocket["host"] = "0.0.0.0"
        changed = True

    if websocket.get("host") in _WILDCARD_HOSTS:
        token = str(websocket.get("token") or "").strip()
        secret = str(
            websocket.get("tokenIssueSecret") or websocket.get("token_issue_secret") or ""
        ).strip()
        trusted_proxy = websocket.get("trustedProxyAuth") or websocket.get("trusted_proxy_auth")
        if not token and not secret and trusted_proxy is None:
            secret = os.environ.get("NANOBOT_WEB_TOKEN") or secrets.token_hex(16)
            websocket["tokenIssueSecret"] = secret
            changed = True
            print(f"[entrypoint] WebUI password: {secret}")

    if not changed:
        return

    backup = path.with_name(path.name + ".pre-0.4.0.bak")
    pending: Path | None = None
    try:
        if not backup.exists():
            backup.write_bytes(raw.encode("utf-8"))
        mode = path.stat().st_mode
        pending = path.with_name(f".{path.name}.tmp-{os.getpid()}")
        pending.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        os.chmod(pending, mode)
        os.replace(pending, path)
    except OSError as exc:
        if pending is not None:
            pending.unlink(missing_ok=True)
        print(f"[entrypoint] warning: could not update {path}: {exc}", file=sys.stderr)
        return
    print(f"[entrypoint] updated {path} for Docker access (backup: {backup})")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} CONFIG", file=sys.stderr)
        return 2
    path = Path(sys.argv[1]).expanduser()
    if not path.exists():
        initialize_config(path)
    else:
        _update(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
