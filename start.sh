#!/bin/bash

# Absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
DEPS_RALPH_SKILLS="$SCRIPT_DIR/deps/ralph/skills"
DEPS_RALPH_CLAUDE_MD="$SCRIPT_DIR/deps/ralph/CLAUDE.md"
PODMAN_SOCKET="/run/user/$UID/podman/podman.sock"
DOCKER_MAPPING_ARGS=()

echo "Checking for Podman socket connection"
# TODO: add the ossibility for the user to choose between total isolation (for insecure code sources) or docker access with prompt injection possibility from insecure code
if [ -S "$PODMAN_SOCKET" ]; then
    chmod 666 "$PODMAN_SOCKET"
    DOCKER_MAPPING_ARGS=(
        "-e" "DOCKER_HOST=unix:///run/user/1000/podman/podman.sock"
        "-v" "$PODMAN_SOCKET:/run/user/1000/podman/podman.sock"
    )
    echo "Podman socket detected. Claude will have access to Docker/Compose"
else
    echo "WARNING: Podman Socket not detected at: $PODMAN_SOCKET"
    echo "Claude will work normally and isolated, but wont be able to run or test containers"
    echo "To turn it on run on your host: systemctl --user enable --now podman.socket"
    echo ""
    sleep 2
fi

echo "Grounding Ralph with: $PROJECT_NAME"

# Build
podman build -t grounded-ralph -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"

CONTAINER_NAME="claude-$PROJECT_NAME"

if podman container exists "$CONTAINER_NAME"; then
    echo "Reconnecting to container: $CONTAINER_NAME..."
    podman start -ai "$CONTAINER_NAME"
else
    echo "Creating new container: $CONTAINER_NAME..."
    # 1. Include the podman socket mapping so claude can manage docker containers on the host
    # 2. Maps project
    # 3. Mounts the host .claude configs on the container lowercase z for multiple project container opene
    # 4. Add Ralph skills to the workspace
    # 5. CLAUDE.md: Copies the Ralph loop dep CLAUDE.md to the workspace root
    # 6. Copies the ralph script

    podman run -it \
      --name "$CONTAINER_NAME" \
      --hostname "$CONTAINER_NAME" \
      --workdir "/workspace" \
      -e "HOME=/root" \
      --security-opt label=disable \
      "${DOCKER_MAPPING_ARGS[@]}" \
      -v "$HOME/.gitconfig:/root/.gitconfig:ro" \
      -v "$PROJECT_ROOT:/workspace/$PROJECT_NAME:Z" \
      -v "$HOME/.claude:/root/.claude:z,U" \
      -v "$DEPS_RALPH_SKILLS:/workspace/skills:U,Z" \
      -v "$DEPS_RALPH_CLAUDE_MD:/workspace/CLAUDE.md:U,Z" \
      -v "$SCRIPT_DIR/deps/ralph/ralph.sh:/workspace/ralph.sh:U,Z" \
      grounded-ralph /bin/bash
fi
