# ~/claude-runner/Containerfile
FROM fedora:latest

# Install system deps
RUN dnf install -y nodejs npm git python3 python3-pip curl procps-ng docker-cli && \
     mkdir -p /usr/local/lib/docker/cli-plugins && \
     curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose && \
     chmod +x /usr/local/lib/docker/cli-plugins/docker-compose && \
     dnf clean all

#Makes sure socket path exists
RUN mkdir -p /run/user/1000/podman

# Install tools
RUN npm install -g @anthropic-ai/claude-code
RUN pip3 install python-lsp-server[all] pyright
RUN npm install -g typescript typescript-language-server eslint prettier
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Prevent pushes
RUN git config --system core.sshCommand "echo 'SSH Disabled in Container'" && \
    git config --system remote.pushDefault no-push && \
    git config --system alias.push "!echo 'Push Disabled in Container'"

WORKDIR /workspace
