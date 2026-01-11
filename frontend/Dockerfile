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
    echo 'if [ -z "$BACKEND_SERVICE" ]; then' >> /docker-entrypoint.sh && \
    echo '  export BACKEND_SERVICE=your-username-backend' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo 'envsubst '"'"'$BACKEND_SERVICE'"'"' < /tmp/nginx.conf.template > /etc/nginx/conf.d/default.conf' >> /docker-entrypoint.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Use non-privileged port (Fix #51)
EXPOSE 8080

# Default backend service name (can be overridden via environment variable)
ENV BACKEND_SERVICE=your-username-backend

ENTRYPOINT ["/docker-entrypoint.sh"]
