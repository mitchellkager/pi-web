# pi-web deployment image: builds the Next.js app from this checkout.
#
# pi-web is a browser frontend that spawns the pi coding agent in-process,
# so this is a minimal dev environment, not just a web server image:
# node (npm ci / next build), git, common agent tooling, and the Docker
# CLI for driving the mounted host docker socket.
#
# This fork is the deployment source for the llm-stack pi-web service
# (tofulab repo, services/llm-stack/docker-compose.yml): the compose
# build context is this checkout, so fork changes ship after
# `docker compose build pi-web`.
#
# At runtime the container's working directory is set by compose to the
# repo pi sessions work in; the launcher below always runs `next start`
# from /app (its own directory) regardless of that cwd.
FROM node:22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates gnupg less ripgrep unzip build-essential \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI + compose plugin: manages the host's containers via the
# mounted /var/run/docker.sock (no daemon runs in this container).
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh): git/GitHub tooling for the agent (issue/PR work, repo
# browsing). The cli/cli releases no longer ship the archive keyring GPG,
# so install the pinned release .deb directly instead of the apt repo.
RUN curl -fsSL -o /tmp/gh.deb https://github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_linux_amd64.deb \
    && dpkg -i /tmp/gh.deb \
    && rm /tmp/gh.deb

WORKDIR /app

# Dependencies first so npm ci is layer-cached across source changes.
# bin/ is copied too: the postinstall hook (prepare-terminal.js) lives there.
COPY package.json package-lock.json ./
COPY bin/ ./bin/
RUN npm ci

# qmd: search backend required by the pi-memory extension (memory_search /
# semantic search). pi-memory resolves it via the `qmd` binary on PATH;
# a global install lands in /usr/local/bin, which is on the default PATH.
RUN npm install -g @tobilu/qmd

# App sources, then the production Next.js bundle (next build --webpack).
COPY . .
RUN npm run build

# Port/hostname come from the container env (PI_WEB_* / PORT).
CMD ["node", "/app/bin/pi-web.js"]
