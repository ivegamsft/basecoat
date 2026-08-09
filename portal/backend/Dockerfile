# Stage 1: builder
FROM node:20-alpine AS builder
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
WORKDIR /app
COPY package*.json ./
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci
COPY src ./src
COPY tsconfig.json ./
RUN npm run build

# Stage 2: runtime
FROM node:20-alpine AS runtime
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
WORKDIR /app
COPY package*.json ./
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci --omit=dev
COPY --from=builder /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
