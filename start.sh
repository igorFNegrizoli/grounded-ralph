#!/bin/bash

# Argument parsing
ISOLATED=false
for arg in "$@"; do
    case $arg in
        --isolated)
            ISOLATED=true
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--isolated]"
            exit 1
            ;;
    esac
done

# Absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
DEPS_RALPH_SKILLS="$SCRIPT_DIR/deps/ralph/skills"
DEPS_RALPH_CLAUDE_MD="$SCRIPT_DIR/deps/ralph/CLAUDE.md"
PODMAN_SOCKET="/run/user/$UID/podman/podman.sock"
DOCKER_MAPPING_ARGS=()

echo "Checking for Podman socket connection"

if [ "$ISOLATED" = true ]; then
    echo "FULLY ISOLATED MODE: Socket access disabled. Claude cannot manage containers."
    echo "Use this mode for untrusted or external code sources."
elif [ -S "$PODMAN_SOCKET" ]; then
    chmod 666 "$PODMAN_SOCKET"
    DOCKER_MAPPING_ARGS=(
        "-e" "DOCKER_HOST=unix:///run/user/1000/podman/podman.sock"
        "-v" "$PODMAN_SOCKET:/run/user/1000/podman/podman.sock"
    )
else
    echo "WARNING: Podman Socket not detected at: $PODMAN_SOCKET"
    echo "Claude will work normally and isolated, but wont be able to run or test containers"
    echo "To turn it on run on your host: systemctl --user enable --now podman.socket"
    echo ""
    sleep 2
fi

echo "Isolating Ralph with: $PROJECT_NAME"

# Build
podman build -t ralph-on-detention -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"

CONTAINER_NAME="claude-$PROJECT_NAME"

if podman container exists "$CONTAINER_NAME"; then
    # Detect mode the container was created with
    SOCKET_IN_CONTAINER=$(podman inspect "$CONTAINER_NAME" \
        --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' \
        | grep -c "podman.sock")
    if [ "$SOCKET_IN_CONTAINER" -gt 0 ]; then
        echo "Reconnecting to: $CONTAINER_NAME (Socket mode - Claude can manage containers)"
    else
        echo "Reconnecting to: $CONTAINER_NAME (Full isolation mode - no container access)"
    fi
    podman start -ai "$CONTAINER_NAME"
else
    if [ "$ISOLATED" = true ]; then
        echo "Creating new container: $CONTAINER_NAME (Fully isolated mode)"
    else
        echo "Creating new container: $CONTAINER_NAME (Socket mode - Claude can manage containers)"
        echo "WARNING: Claude has access to your host's Podman socket."
        echo "Only use this mode with trusted projects."
        echo "For untrusted sources, use: $0 --isolated"
    fi

    # 1. Include the podman socket mapping so claude can manage docker containers on the host
    # 2. Maps project
    # 3. Mounts the host .claude configs on the container lowercase z for multiple project container opene
    # 4. Add Ralph skills to the workspace
    # 5. CLAUDE.md: Copies the Ralph loop dep CLAUDE.md to the workspace root
    # 6. Copies the ralph script

    # Support for symlinks on the claude config
    TMP_CLAUDE=$(mktemp -d)
    cp -rL "$HOME/.claude/." "$TMP_CLAUDE/"

    podman run -it \
      --name "$CONTAINER_NAME" \
      --hostname "$CONTAINER_NAME" \
      --workdir "/workspace" \
      -e "HOME=/root" \
      --security-opt label=disable \
      "${DOCKER_MAPPING_ARGS[@]}" \
      -v "$HOME/.gitconfig:/root/.gitconfig:ro" \
      -v "$PROJECT_ROOT:/workspace/$PROJECT_NAME:Z" \
      -v "$TMP_CLAUDE:/root/.claude:z" \
      -v "$DEPS_RALPH_SKILLS:/workspace/skills:U,Z" \
      -v "$DEPS_RALPH_CLAUDE_MD:/workspace/CLAUDE.md:U,Z" \
      -v "$SCRIPT_DIR/deps/ralph/ralph.sh:/workspace/ralph.sh:U,Z" \
      ralph-on-detention /bin/bash
fi
