FROM node:22-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git jq ripgrep \
 && rm -rf /var/lib/apt/lists/*

# Pinned. Bump deliberately; the autoupdater is disabled at runtime.
RUN npm install -g @anthropic-ai/claude-code@2.1.316 && npm cache clean --force

# HOME lives on a named volume; pre-create it so agent-bot (1040:100) owns it.
RUN mkdir -p /home/agent && chown 1040:100 /home/agent

# The runner is baked in so the agent can't edit its own control loop.
COPY runner.mjs /opt/agent/runner.mjs

USER 1040:100
ENV HOME=/home/agent
CMD ["node", "/opt/agent/runner.mjs"]
