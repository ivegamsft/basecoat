# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM node:22-alpine AS builder
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
WORKDIR /build
COPY package*.json ./
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000

ENV NODE_ENV=production \
    MCP_TRANSPORT=http \
    PORT=8080

RUN addgroup -S mcp && adduser -S mcp -G mcp

WORKDIR /app
COPY package*.json ./
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci --omit=dev \
    && npm cache clean --force

COPY --from=builder /build/dist ./dist

USER mcp
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "dist/index.js"]
