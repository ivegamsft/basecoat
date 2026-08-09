FROM node:22-alpine

ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000

WORKDIR /app

COPY mcp/package*.json ./mcp/
RUN test -n "${NPM_REGISTRY:-}" \
    && cd mcp \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci --omit=dev

COPY README.md CHANGELOG.md version.json ./
COPY instructions ./instructions
COPY skills ./skills
COPY prompts ./prompts
COPY agents ./agents
COPY docs ./docs
COPY examples ./examples
COPY scripts ./scripts
COPY .github ./.github
COPY mcp ./mcp

ENTRYPOINT ["node", "/app/mcp/index.js"]
