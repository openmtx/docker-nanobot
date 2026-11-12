#!/usr/bin/env python3
"""End-to-end probe for nanobot's shared-proxy forwarding to mst.

Starts a logging HTTP proxy in this process, then runs nanobot's ``mst``
web-search tool with ``proxy=<that proxy>``. mst engines speak HTTPS, so the
proxy logs each ``CONNECT host:port`` it tunnels. PASS means the search traffic
actually left through the configured proxy.

Run inside the nanobot image or a running container::

    docker exec -i <container> python - < scripts/test-mst-proxy.py

    docker run --rm -i --entrypoint python ghcr.io/openmtx/nanobot:0.4.1 \
        - < scripts/test-mst-proxy.py

The probe sets ``network.proxy`` and ``tools.web.useProxy`` exactly like the
gateway config does, so a PASS covers config resolution, tool wiring, and mst's
per-call proxy handling. Running it inside the container also works with no
host networking changes.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import threading
from urllib.parse import urlsplit


class LoggingProxy:
    """Threaded HTTP proxy that records CONNECT/absolute-form destinations."""

    def __init__(self) -> None:
        self.hosts: list[str] = []
        self._lock = threading.Lock()
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._thread.start()
        self._server = asyncio.run_coroutine_threadsafe(
            asyncio.start_server(self._handle, "127.0.0.1", 0), self._loop
        ).result(10)
        self.port = self._server.sockets[0].getsockname()[1]

    def _record(self, host: str) -> None:
        with self._lock:
            self.hosts.append(host)

    def snapshot(self) -> list[str]:
        with self._lock:
            return list(self.hosts)

    async def _pipe(
        self,
        src: asyncio.StreamReader,
        dst: asyncio.StreamWriter,
        other_src: asyncio.StreamReader,
        other_dst: asyncio.StreamWriter,
    ) -> None:
        async def pump(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
            try:
                while data := await reader.read(65536):
                    writer.write(data)
                    await writer.drain()
            except (ConnectionError, asyncio.CancelledError):
                pass
            finally:
                writer.close()

        await asyncio.gather(pump(src, dst), pump(other_src, other_dst))

    async def _handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            head = await reader.readuntil(b"\r\n\r\n")
        except (ConnectionError, asyncio.IncompleteReadError, asyncio.LimitOverrunError):
            writer.close()
            return

        try:
            method, target, version = head.split(b"\r\n", 1)[0].decode("latin-1").split(" ")
        except ValueError:
            writer.write(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            await writer.drain()
            writer.close()
            return

        if method.upper() == "CONNECT":
            host, _, raw_port = target.rpartition(":")
            try:
                port = int(raw_port)
            except ValueError:
                host, port = target, 443
            self._record(host)
            try:
                remote_reader, remote_writer = await asyncio.open_connection(host, port)
            except OSError:
                writer.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
                await writer.drain()
                writer.close()
                return
            writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            await writer.drain()
            await self._pipe(reader, remote_writer, remote_reader, writer)
            return

        parsed = urlsplit(target)
        host = parsed.hostname or ""
        port = parsed.port or 80
        if not host:
            writer.close()
            return
        self._record(host)
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query
        rewritten = (
            f"{method} {path} {version}\r\n".encode("latin-1")
            + head.split(b"\r\n", 1)[1]
        )
        try:
            remote_reader, remote_writer = await asyncio.open_connection(host, port)
        except OSError:
            writer.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
            await writer.drain()
            writer.close()
            return
        remote_writer.write(rewritten)
        await remote_writer.drain()
        await self._pipe(reader, remote_writer, remote_reader, writer)

    def close(self) -> None:
        self._loop.call_soon_threadsafe(self._server.close)
        self._loop.call_soon_threadsafe(self._loop.stop)
        self._thread.join(timeout=5)


async def probe(proxy: str, query: str) -> str:
    from nanobot.agent.tools.context import ToolContext
    from nanobot.agent.tools.web import WebSearchTool
    from nanobot.agent.tools.web_config import WebSearchConfig, WebToolsConfig
    from nanobot.config.network import NetworkConfig
    from nanobot.config.schema import ToolsConfig

    # Resolve the tool from config, the same way the gateway does: shared proxy
    # plus web.useProxy=True must arrive as the tool's proxy.
    context = ToolContext(
        config=ToolsConfig(
            web=WebToolsConfig(
                use_proxy=True,
                search=WebSearchConfig(provider="mst", max_results=3, timeout=10),
            )
        ),
        workspace="/tmp",
        network=NetworkConfig(proxy=proxy),
    )
    tool = WebSearchTool.create(context)
    if tool.proxy != proxy:
        raise RuntimeError(f"config did not reach the tool: proxy={tool.proxy!r}")
    result = await asyncio.wait_for(tool.execute(query, count=3), timeout=120)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", default="nanobot agent framework", help="Search query")
    args = parser.parse_args()

    local_proxy = LoggingProxy()
    proxy_url = f"http://127.0.0.1:{local_proxy.port}"

    print(f"proxy:    {proxy_url}")
    print(f"query:    {args.query}")
    try:
        result = asyncio.run(probe(proxy_url, args.query))
    except Exception as exc:
        print(f"FAIL: probe raised {type(exc).__name__}: {exc}")
        return 2
    finally:
        hosts = local_proxy.snapshot()
        local_proxy.close()

    print(f"proxied:  {len(hosts)} connection(s)")
    for host in dict.fromkeys(hosts):
        print(f"  CONNECT {host}")

    print("result:")
    for line in result.splitlines()[:8]:
        print(f"  {line}")
    if result.startswith("Error:"):
        print("FAIL: web_search returned an error")
        return 1
    if not hosts:
        print("FAIL: no traffic reached the proxy; mst did not honor the proxy setting")
        return 1

    print("PASS: mst search ran through the configured proxy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
