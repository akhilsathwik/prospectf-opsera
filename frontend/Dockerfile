# Frontend Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration template
COPY nginx.conf /tmp/nginx.conf.template

# Create startup script to substitute environment variables
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo 'BACKEND_SERVICE=${BACKEND_SERVICE:-your-username-backend}' >> /docker-entrypoint.sh && \
    echo 'echo "=== Frontend Startup ==="' >> /docker-entrypoint.sh && \
    echo 'echo "Using backend service: $BACKEND_SERVICE"' >> /docker-entrypoint.sh && \
    echo 'echo "Substituting BACKEND_SERVICE in nginx.conf..."' >> /docker-entrypoint.sh && \
    echo 'sed "s|\${BACKEND_SERVICE}|$BACKEND_SERVICE|g" /tmp/nginx.conf.template > /etc/nginx/conf.d/default.conf' >> /docker-entrypoint.sh && \
    echo 'if [ $? -ne 0 ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "ERROR: sed substitution failed!"' >> /docker-entrypoint.sh && \
    echo '  exit 1' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo 'echo "Nginx configuration generated successfully"' >> /docker-entrypoint.sh && \
    echo 'echo "Verifying proxy_pass directives:"' >> /docker-entrypoint.sh && \
    echo 'grep -n "proxy_pass" /etc/nginx/conf.d/default.conf | head -3 || echo "No proxy_pass found (this is OK if not needed)"' >> /docker-entrypoint.sh && \
    echo 'echo "Testing nginx configuration..."' >> /docker-entrypoint.sh && \
    echo 'nginx -t' >> /docker-entrypoint.sh && \
    echo 'if [ $? -ne 0 ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "ERROR: nginx configuration test failed!"' >> /docker-entrypoint.sh && \
    echo '  cat /etc/nginx/conf.d/default.conf' >> /docker-entrypoint.sh && \
    echo '  exit 1' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo 'echo "Starting nginx..."' >> /docker-entrypoint.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Use non-privileged port (Fix #51)
EXPOSE 8080

# Default backend service name (can be overridden via environment variable)
ENV BACKEND_SERVICE=your-username-backend

ENTRYPOINT ["/docker-entrypoint.sh"]
