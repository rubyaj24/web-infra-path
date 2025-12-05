# ![Docker](../images/logos/docker.svg) Docker Fundamentals for SaaS Applications

![Docker Architecture](../images/docker-architecture.png)
*Docker containerization architecture with images, containers, and registries*

## Overview

Docker is essential for modern SaaS development, providing consistent environments across development, testing, and production. This comprehensive guide covers Docker fundamentals, best practices for SaaS applications, and advanced containerization strategies.

## Docker Basics

### 1. Understanding Docker Components

![Docker Components](../images/docker-components.png)

**Docker Engine**: The runtime that manages containers
**Images**: Read-only templates used to create containers
**Containers**: Running instances of Docker images
**Dockerfile**: Text file with instructions to build images
**Docker Registry**: Storage and distribution system for images

### 2. Installing Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group (avoid using sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker run hello-world
```

```powershell
# Windows (PowerShell as Administrator)
# Download Docker Desktop from docker.com
# Install and restart system
# Verify installation
docker --version
docker run hello-world
```

## Creating Docker Images

### 1. Basic Dockerfile for Node.js SaaS App

```dockerfile
# Use official Node.js runtime as base image
FROM node:18-alpine AS base

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

# Start application
CMD ["node", "server.js"]
```

### 2. Multi-Stage Build for Optimization

```dockerfile
# Multi-stage build for Node.js SaaS application
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci

# Copy source code
COPY . .

# Build application
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# Production stage
FROM node:18-alpine AS production

# Install security updates
RUN apk --no-cache upgrade

# Create app directory
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "dist/server.js"]
```

### 3. Python FastAPI Dockerfile

```dockerfile
# Python SaaS application Dockerfile
FROM python:3.11-slim AS base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start application with gunicorn
CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000"]
```

## Docker Compose for Local Development

### 1. Complete Development Environment

```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: saas_app
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/saas_app
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=dev-secret-key
    volumes:
      - ./backend:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  # Frontend App
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    environment:
      - REACT_APP_API_URL=http://localhost:3000/api
    volumes:
      - ./frontend:/app
      - /app/node_modules
    ports:
      - "3001:3000"
    depends_on:
      - backend
    restart: unless-stopped

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx/nginx.dev.conf:/etc/nginx/nginx.conf
      - ./nginx/logs:/var/log/nginx
    ports:
      - "80:80"
    depends_on:
      - backend
      - frontend
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  default:
    name: saas-network
```

### 2. Production Docker Compose

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: always
    networks:
      - backend-network

  redis:
    image: redis:7-alpine
    volumes:
      - redis_prod_data:/data
    restart: always
    networks:
      - backend-network

  backend:
    image: myregistry/saas-backend:${VERSION}
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    restart: always
    networks:
      - backend-network
      - frontend-network

  frontend:
    image: myregistry/saas-frontend:${VERSION}
    environment:
      - REACT_APP_API_URL=${API_URL}
    restart: always
    networks:
      - frontend-network

  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx/nginx.prod.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
      - ./nginx/logs:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend
      - frontend
    restart: always
    networks:
      - frontend-network

volumes:
  postgres_prod_data:
  redis_prod_data:

networks:
  backend-network:
    driver: bridge
  frontend-network:
    driver: bridge
```

## Docker Best Practices for SaaS

### 1. Security Best Practices

```dockerfile
# Security-focused Dockerfile
FROM node:18-alpine AS base

# Update packages for security
RUN apk --no-cache upgrade

# Create app directory
WORKDIR /app

# Don't run as root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy package files with correct ownership
COPY --chown=nodejs:nodejs package*.json ./

# Install dependencies as root, then switch
RUN npm ci --only=production && \
    npm cache clean --force

# Copy app source
COPY --chown=nodejs:nodejs . .

# Remove unnecessary packages
RUN apk del curl wget

# Switch to non-root user
USER nodejs

# Use specific port
EXPOSE 3000

# Use exec form for proper signal handling
CMD ["node", "server.js"]
```

### 2. Multi-Environment Configuration

```dockerfile
# Dockerfile with build args for different environments
FROM node:18-alpine AS base

# Build arguments
ARG NODE_ENV=production
ARG BUILD_VERSION=latest

# Environment variables
ENV NODE_ENV=${NODE_ENV}
ENV BUILD_VERSION=${BUILD_VERSION}

WORKDIR /app

# Copy package files
COPY package*.json ./

# Conditional dependency installation
RUN if [ "$NODE_ENV" = "development" ] ; then \
        npm ci ; \
    else \
        npm ci --only=production ; \
    fi

COPY . .

# Conditional build steps
RUN if [ "$NODE_ENV" = "production" ] ; then \
        npm run build && \
        npm prune --production ; \
    fi

# Security user
RUN adduser -D -s /bin/sh nodejs
USER nodejs

EXPOSE 3000

# Conditional startup
CMD if [ "$NODE_ENV" = "development" ] ; then \
        npm run dev ; \
    else \
        npm start ; \
    fi
```

### 3. Health Checks and Monitoring

```dockerfile
# Advanced health check setup
FROM node:18-alpine

WORKDIR /app

# Install health check dependencies
RUN apk add --no-cache curl

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Create health check script
RUN echo '#!/bin/sh\n\
curl -f http://localhost:3000/health || exit 1\n\
' > /app/healthcheck.sh && chmod +x /app/healthcheck.sh

# Advanced health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /app/healthcheck.sh

# Add labels for monitoring
LABEL maintainer="devops@mycompany.com" \
      version="1.0.0" \
      description="SaaS Backend API" \
      monitoring.enabled="true"

EXPOSE 3000

CMD ["node", "server.js"]
```

### 4. Health Check Endpoint Implementation

```javascript
// healthcheck.js - Comprehensive health check
const http = require('http');
const { PrismaClient } = require('@prisma/client');
const redis = require('redis');

const prisma = new PrismaClient();
const redisClient = redis.createClient(process.env.REDIS_URL);

async function healthCheck() {
    const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: {}
    };

    try {
        // Check database connectivity
        await prisma.$queryRaw`SELECT 1`;
        health.services.database = { status: 'healthy' };
    } catch (error) {
        health.services.database = { 
            status: 'unhealthy', 
            error: error.message 
        };
        health.status = 'unhealthy';
    }

    try {
        // Check Redis connectivity
        await redisClient.ping();
        health.services.redis = { status: 'healthy' };
    } catch (error) {
        health.services.redis = { 
            status: 'unhealthy', 
            error: error.message 
        };
        health.status = 'unhealthy';
    }

    // Check memory usage
    const memUsage = process.memoryUsage();
    health.services.memory = {
        status: memUsage.heapUsed < 1024 * 1024 * 500 ? 'healthy' : 'warning', // 500MB threshold
        heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
        heapTotal: `${Math.round(memUsage.heapTotal / 1024 / 1024)}MB`
    };

    return health;
}

// For command-line health check (used in Docker HEALTHCHECK)
if (require.main === module) {
    const options = {
        hostname: 'localhost',
        port: 3000,
        path: '/health',
        method: 'GET',
        timeout: 5000
    };

    const req = http.request(options, (res) => {
        if (res.statusCode === 200) {
            process.exit(0);
        } else {
            process.exit(1);
        }
    });

    req.on('error', () => {
        process.exit(1);
    });

    req.on('timeout', () => {
        req.destroy();
        process.exit(1);
    });

    req.end();
}

module.exports = { healthCheck };
```

## Container Orchestration with Docker Compose

### 1. Development Environment Setup

```bash
#!/bin/bash
# setup-dev.sh - Development environment setup script

echo "Setting up SaaS development environment..."

# Create necessary directories
mkdir -p logs backups nginx/logs

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env file. Please update with your configuration."
fi

# Build and start services
docker-compose -f docker-compose.yml up --build -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
docker-compose ps

# Run database migrations
echo "Running database migrations..."
docker-compose exec backend npm run migrate

# Create initial admin user
echo "Creating initial admin user..."
docker-compose exec backend npm run seed:admin

echo "Development environment is ready!"
echo "Frontend: http://localhost:3001"
echo "Backend API: http://localhost:3000"
echo "API Docs: http://localhost:3000/docs"
```

### 2. Production Deployment Script

```bash
#!/bin/bash
# deploy-prod.sh - Production deployment script

set -e

# Load environment variables
source .env.prod

# Validate required environment variables
required_vars=("DB_PASSWORD" "JWT_SECRET" "VERSION")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

echo "Deploying SaaS application version: $VERSION"

# Pull latest images
docker-compose -f docker-compose.prod.yml pull

# Backup database before deployment
echo "Creating database backup..."
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U $DB_USER $DB_NAME > ./backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Update application with zero downtime
echo "Performing rolling update..."
docker-compose -f docker-compose.prod.yml up -d --no-recreate --remove-orphans

# Wait for health checks
echo "Waiting for health checks..."
sleep 30

# Verify deployment
echo "Verifying deployment..."
if curl -f http://localhost/health; then
    echo "Deployment successful!"
    
    # Clean up old images
    docker image prune -f
    
    # Send notification (example)
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"SaaS deployment successful - Version: '${VERSION}'"}' \
        $SLACK_WEBHOOK_URL
else
    echo "Deployment verification failed!"
    exit 1
fi
```

## Docker Registry and Image Management

### 1. Building and Pushing Images

```bash
#!/bin/bash
# build-and-push.sh - Build and push Docker images

# Configuration
REGISTRY="your-registry.com"
PROJECT="saas-app"
VERSION=${1:-latest}

# Build backend image
echo "Building backend image..."
docker build -t ${REGISTRY}/${PROJECT}/backend:${VERSION} \
    -f backend/Dockerfile \
    --build-arg BUILD_VERSION=${VERSION} \
    backend/

# Build frontend image
echo "Building frontend image..."
docker build -t ${REGISTRY}/${PROJECT}/frontend:${VERSION} \
    -f frontend/Dockerfile \
    --build-arg BUILD_VERSION=${VERSION} \
    frontend/

# Security scanning
echo "Scanning images for vulnerabilities..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(pwd):/project \
    aquasec/trivy image ${REGISTRY}/${PROJECT}/backend:${VERSION}

# Push images
echo "Pushing images to registry..."
docker push ${REGISTRY}/${PROJECT}/backend:${VERSION}
docker push ${REGISTRY}/${PROJECT}/frontend:${VERSION}

# Tag as latest if version is not 'latest'
if [ "$VERSION" != "latest" ]; then
    docker tag ${REGISTRY}/${PROJECT}/backend:${VERSION} ${REGISTRY}/${PROJECT}/backend:latest
    docker tag ${REGISTRY}/${PROJECT}/frontend:${VERSION} ${REGISTRY}/${PROJECT}/frontend:latest
    docker push ${REGISTRY}/${PROJECT}/backend:latest
    docker push ${REGISTRY}/${PROJECT}/frontend:latest
fi

echo "Images built and pushed successfully!"
```

### 2. Image Optimization

```dockerfile
# Optimized Node.js Dockerfile
FROM node:18-alpine AS dependencies

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Final production stage
FROM node:18-alpine AS production

# Install security updates
RUN apk --no-cache upgrade

# Add non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

# Copy production dependencies
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package*.json ./

# Remove unnecessary files
RUN rm -rf /app/src /app/tests /app/.git

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "dist/server.js"]
```

## Debugging and Troubleshooting

### 1. Container Debugging

```bash
# Common Docker debugging commands

# Check container logs
docker-compose logs -f backend

# Access container shell
docker-compose exec backend sh

# Check container resource usage
docker stats

# Inspect container details
docker inspect <container_name>

# View container filesystem changes
docker diff <container_name>

# Debug network connectivity
docker-compose exec backend ping postgres
docker-compose exec backend nc -zv postgres 5432

# Check port bindings
docker port <container_name>

# View container processes
docker-compose exec backend ps aux
```

### 2. Performance Monitoring

```bash
#!/bin/bash
# monitor-containers.sh - Container performance monitoring

echo "Container Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo -e "\nContainer Health Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\nDisk Usage:"
docker system df

echo -e "\nImage Vulnerabilities:"
for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do
    echo "Scanning $image..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy image --severity HIGH,CRITICAL --quiet $image
done
```

## Sources and References

### Official Documentation
- [Docker Documentation](https://docs.docker.com/) - Comprehensive Docker documentation
- [Docker Compose Documentation](https://docs.docker.com/compose/) - Multi-container application management
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Official best practices guide
- [Docker Security](https://docs.docker.com/engine/security/) - Security guidelines and practices

### Best Practices Guides
- [Docker Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) - OWASP security guidelines
- [12-Factor App with Docker](https://12factor.net/) - Modern application development principles
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/#use-multi-stage-builds) - Optimizing image size

### Security Resources
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Security configuration guidelines
- [Trivy Scanner](https://github.com/aquasecurity/trivy) - Vulnerability scanner for containers
- [Docker Scout](https://docs.docker.com/scout/) - Docker's official security scanning

### Books
- "Docker Deep Dive" by Nigel Poulton
- "Docker in Action" by Jeff Nickoloff
- "Kubernetes in Action" by Marko Lukša

### Tools and Resources
- [Docker Desktop](https://www.docker.com/products/docker-desktop) - Development environment
- [Portainer](https://www.portainer.io/) - Container management UI
- [Watchtower](https://containrrr.dev/watchtower/) - Automatic container updates
- [Docker Hub](https://hub.docker.com/) - Public container registry

---

**Next:** [Production Deployment Guide](../04-deployment-scaling/production-deployment.md)