# =============================================================================
# Multi-stage Dockerfile — industry best practice
#
# Stage 1 (builder): install ALL dependencies including devDependencies
# Stage 2 (production): copy only what's needed, no dev tools
#
# Why multi-stage?
#   - Final image has no jest, nodemon, or other dev tools
#   - Smaller image = faster pulls, smaller attack surface
#   - node_modules only contains production dependencies
# =============================================================================

# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first — Docker layer caching
# If package.json didn't change, this layer is cached (faster builds)
COPY package*.json ./

# Install ALL dependencies (including devDependencies for tests)
RUN npm ci

# Copy source code
COPY . .

# ── Stage 2: Production ───────────────────────────────────────────────────────
FROM node:18-alpine AS production

# Create non-root user — security best practice
# Running as root inside a container is a security risk
RUN addgroup -g 1001 -S nodejs && \
    adduser -S reviews -u 1001 -G nodejs

WORKDIR /app

# Copy only package files
COPY package*.json ./

# Install ONLY production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source from builder stage
COPY --from=builder /app/src ./src

# Switch to non-root user
USER reviews

# Document the port (doesn't actually expose — that's done in K8s)
EXPOSE 8090

# Health check — Docker will mark container unhealthy if this fails
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8090/health/live', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Start the service
CMD ["node", "src/index.js"]
