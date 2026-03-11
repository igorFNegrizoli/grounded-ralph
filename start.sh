#!/bin/bash

# Caminhos Absolutos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
HOST_CLAUDE="$HOME/.claude"
DEPS_RALPH_SKILLS="$SCRIPT_DIR/deps/ralph/skills"
STAGING_DIR="/tmp/claude-staging-$PROJECT_NAME"

echo "Configurando Ralph para: $PROJECT_NAME"

# 1. Limpeza e Recriação do Staging
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/skills" "$STAGING_DIR/agents"

# 2. Copiar Skills do Host (~/.claude/skills)
if [ -d "$HOST_CLAUDE/skills" ]; then
    echo "Copiando skills do host..."
    cp -rP "$HOST_CLAUDE/skills/." "$STAGING_DIR/skills/"
fi

# 3. Mesclar Skills do Projeto (ralph/skills) - SEM SOBRESCREVER as do host
if [ -d "$DEPS_RALPH_SKILLS" ]; then
    echo "Mesclando skills do Ralph..."
    # Usamos 'cp -n' (no-clobber) para não deletar o que já está lá, ou apenas cp -r 
    # para adicionar os novos arquivos de skill do ralph
    cp -rP "$DEPS_RALPH_SKILLS/." "$STAGING_DIR/skills/"
fi

# 4. Copiar Agents do Host (~/.claude/agents)
if [ -d "$HOST_CLAUDE/agents" ]; then
    echo "Copiando agents do host..."
    cp -rP "$HOST_CLAUDE/agents/." "$STAGING_DIR/agents/"
fi

# 5. Gerar CLAUDE.md unificado
cat "$PROJECT_ROOT/CLAUDE.md" "$SCRIPT_DIR/deps/ralph/CLAUDE.md" > "$STAGING_DIR/CLAUDE.merged.md" 2>/dev/null

# 6. Build
podman build -t claude-dev -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"

# 7. Execução
# Nota: Adicionei :U no volume do staging para o Podman ajustar o dono (User) dentro do container
echo "Running..."
podman run -it --rm \
  --name "claude-$PROJECT_NAME" \
  --hostname "claude-$PROJECT_NAME" \
  -v "$PROJECT_ROOT:/workspace/$PROJECT_NAME:Z" \
  -v "$STAGING_DIR:/root/.claude:Z,U" \
  -v "$STAGING_DIR/CLAUDE.merged.md:/workspace/CLAUDE.md:Z" \
  -v "$SCRIPT_DIR/deps/ralph/ralph.sh:/workspace/ralph.sh:Z" \
  -e "HOME=/root" \
  -w "/workspace" \
  claude-dev /bin/bash
