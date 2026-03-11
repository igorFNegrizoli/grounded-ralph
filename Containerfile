# ~/claude-runner/Containerfile
FROM fedora:latest

# Instala dependências do sistema, Node.js, Python e Just
ARG COMPOSE_VERSION=v2.24.5

RUN dnf install -y nodejs npm git python3 python3-pip curl procps-ng docker-cli && \
     mkdir -p /usr/local/lib/docker/cli-plugins && \
     curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose && \
     chmod +x /usr/local/lib/docker/cli-plugins/docker-compose && \
     dnf clean all

#Makes sure socket path exists
RUN mkdir -p /run/user/1000/podman

# Instala Claude Code globalmente
RUN npm install -g @anthropic-ai/claude-code
# Instala ferramentas de LSP e Python
RUN pip3 install python-lsp-server[all] pyright
# Instala ferramentas de Node LSP
RUN npm install -g typescript typescript-language-server eslint prettier
# Instala o Task Runner 'Just'
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Configurações de Git (idêntico ao seu anterior)
RUN git config --system user.name "Igor F. Negrizoli" && \
    git config --system user.email "igor.negrizoli@gmail.com" && \
    git config --system core.sshCommand "echo 'SSH Disabled in Container'" && \
    git config --system alias.push "!echo 'Push Disabled in Container'"

WORKDIR /workspace
