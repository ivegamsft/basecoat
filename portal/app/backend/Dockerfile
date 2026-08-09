FROM node:22-alpine AS builder
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Production stage
FROM node:22-alpine
ARG NPM_REGISTRY
ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000

WORKDIR /app

# Install only production dependencies
COPY package*.json ./
RUN test -n "${NPM_REGISTRY:-}" \
    && NPM_CONFIG_REGISTRY="${NPM_REGISTRY}" \
       NPM_CONFIG_REPLACE_REGISTRY_HOST=npmjs \
       npm ci --omit=dev

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Create logs directory
RUN mkdir -p logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Expose port
EXPOSE 3000

# Start application
CMD ["node", "dist/src/main.js"]
