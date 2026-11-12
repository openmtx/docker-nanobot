#!/bin/sh
# Run the source checkout's native terminal UI with the bundled Bun runtime.
# The installed Python package cannot discover /app/nanobot as its own source
# checkout, so point the launcher at this wrapper instead of making it download
# a release archive into the data volume on first use.
exec /usr/local/bin/bun /app/nanobot/tui/src/index.ts "$@"
