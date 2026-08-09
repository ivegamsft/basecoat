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
COPY index.html ./
COPY postcss.config.js tailwind.config.js ./
COPY vite.config.ts ./
COPY tsconfig*.json ./
RUN npm run build

# Stage 2: runtime
FROM nginx:alpine AS runtime
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
