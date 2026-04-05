FROM python:3.12-slim

# System deps: bash, git, curl, ssh (for git operations)
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        git \
        curl \
        openssh-client \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI (npm-based)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && rm -rf /var/lib/apt/lists/*

# Python deps
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY conductor.py api.py ./

# Dirs for state and logs (will be volume-mounted)
RUN mkdir -p /data/state /data/logs

# Non-root user matching typical host UID
ARG PUID=1000
ARG PGID=1000
RUN groupadd -g ${PGID} conductor \
    && useradd -u ${PUID} -g conductor -m -s /bin/bash conductor \
    && chown -R conductor:conductor /app /data

USER conductor

# Git config for commits
RUN git config --global user.name "Tekhton Conductor" \
    && git config --global user.email "conductor@tekhton.local"

EXPOSE 7411

ENTRYPOINT ["python3", "/app/conductor.py", "/config/conductor.cfg"]
