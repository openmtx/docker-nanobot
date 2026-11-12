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

# A user-selected config is owned by the CLI, including its first-run behavior.
explicit_config=0
for argument in "$@"; do
    case "$argument" in
        --config|--config=*|-c*) explicit_config=1; break ;;
    esac
done

# Prepare the default instance before starting a service. `onboard` manages its
# own creation flow, so do not pre-create a config and trigger an overwrite
# prompt before it runs.
if [ "$explicit_config" = "0" ] && [ "${1:-}" != "onboard" ]; then
    if [ "${NANOBOT_DOCKER_BOOTSTRAP:-0}" = "1" ]; then
        # Creates a container-friendly config and upgrades 0.3.x loopback binds.
        python /usr/local/bin/docker-config.py "$dir/config.json" || exit 1
    elif [ ! -f "$dir/config.json" ]; then
        nanobot onboard
    fi
fi

exec nanobot "$@"
