#!/bin/sh
# Add user-local bin to PATH if it exists (e.g., mst, webclaw from workspace skills)
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
home="$HOME"
if [ ! -d "$home" ] || [ ! -w "$home" ]; then
    owner_uid=$(stat -c %u "$home" 2>/dev/null || stat -f %u "$home" 2>/dev/null)
    cat >&2 <<EOF
Error: $home is not writable (owned by UID $owner_uid, running as UID $(id -u)).

The home directory is mounted as a volume. Fix the volume permissions:
  chown -R $(id -u):$(id -g) $home
EOF
    exit 1
fi

dir="$HOME/.nanobot"
if [ ! -f "$dir/config.json" ]; then
    nanobot onboard
fi

exec nanobot "$@"
