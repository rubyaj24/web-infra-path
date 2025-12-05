# Resources & Templates

This directory contains shared resources, templates, and utilities that can be used across all phases of SaaS development.

## 📁 Directory Contents

### Configuration Templates
- **Docker Templates** - Dockerfile and docker-compose.yml examples
- **Kubernetes Manifests** - Deployment, service, and ingress templates
- **CI/CD Templates** - GitHub Actions, Jenkins, and GitLab CI examples
- **Cloud Infrastructure** - Terraform and CloudFormation templates

### Development Tools
- **Environment Setup Scripts** - Quick development environment setup
- **Database Scripts** - Migration templates and seed data
- **Testing Templates** - Unit, integration, and load testing examples
- **Documentation Templates** - README, API docs, and architecture decision records

### Monitoring & Operations
- **Dashboard Templates** - Grafana dashboards for common metrics
- **Alert Rules** - Prometheus alerting rules
- **Log Parsing** - Fluentd and Logstash configurations
- **Backup Scripts** - Database and file backup automation

## 🛠️ Quick Start Templates

### Project Initialization
```bash
# Use these templates to quickly start a new SaaS project
./templates/project-init/
├── backend/
│   ├── node-express/
│   ├── python-fastapi/
│   └── python-django/
├── frontend/
│   ├── react-typescript/
│   ├── vue-typescript/
│   └── svelte-kit/
└── fullstack/
    ├── t3-stack/
    ├── next-js-saas/
    └── nuxt-saas/
```

### Infrastructure Templates
```bash
# Infrastructure as code templates
./templates/infrastructure/
├── terraform/
│   ├── aws-saas-basic/
│   ├── aws-saas-advanced/
│   ├── azure-app-service/
│   └── gcp-cloud-run/
├── docker/
│   ├── multi-stage-node/
│   ├── python-production/
│   └── nginx-static/
└── kubernetes/
    ├── basic-deployment/
    ├── with-ingress/
    └── with-monitoring/
```

## 📚 Documentation Templates

### Architecture Decision Records (ADRs)
Template for documenting important architectural decisions:

```markdown
# ADR-001: Database Technology Selection

## Status
Accepted

## Context
We need to choose a database technology for our multi-tenant SaaS application.

## Decision
We will use PostgreSQL with a single database, multiple schema approach.

## Consequences
- Pros: ACID compliance, mature ecosystem, good multi-tenancy support
- Cons: Requires careful schema management, potential scaling limitations
```

### API Documentation Template
```yaml
# OpenAPI 3.0 template for API documentation
openapi: 3.0.0
info:
  title: SaaS API
  version: 1.0.0
  description: RESTful API for SaaS application
paths:
  /api/v1/users:
    get:
      summary: List users
      parameters:
        - name: tenant_id
          in: header
          required: true
          schema:
            type: string
```

## 🔧 Development Scripts

### Environment Setup
```bash
#!/bin/bash
# setup-dev-environment.sh
# Quick development environment setup

echo "Setting up SaaS development environment..."

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Node.js via NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts

# Install Python via pyenv
curl https://pyenv.run | bash
pyenv install 3.11.0
pyenv global 3.11.0

echo "Development environment setup complete!"
```

### Database Migration Template
```sql
-- migrations/001_create_tenants_table.sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tenants_slug ON tenants(slug);
```

## 📊 Monitoring Templates

### Grafana Dashboard JSON
```json
{
  "dashboard": {
    "title": "SaaS Application Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{ method }} {{ endpoint }}"
          }
        ]
      }
    ]
  }
}
```

### Prometheus Alert Rules
```yaml
# alerts/saas-alerts.yml
groups:
  - name: saas-application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 10% for 5 minutes"
```

## 🧪 Testing Templates

### Jest Unit Test Template
```javascript
// tests/unit/user.service.test.js
const UserService = require('../../src/services/user.service');

describe('UserService', () => {
  let userService;
  
  beforeEach(() => {
    userService = new UserService();
  });

  describe('createUser', () => {
    it('should create a user with valid data', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User',
        tenantId: 'tenant-123'
      };

      const result = await userService.createUser(userData);

      expect(result).toHaveProperty('id');
      expect(result.email).toBe(userData.email);
    });
  });
});
```

### Load Testing Script (K6)
```javascript
// tests/load/api-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 },
  ],
};

export default function() {
  let response = http.get('https://your-saas-api.com/api/v1/health');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

## 🔐 Security Templates

### Security Headers Configuration
```nginx
# nginx/security-headers.conf
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

### Environment Variables Template
```env
# .env.template
# Copy to .env and fill in actual values

# Application
APP_NAME="My SaaS App"
APP_ENV="development"
APP_PORT=3000
APP_URL="http://localhost:3000"

# Database
DATABASE_URL="postgresql://user:password@localhost:5432/myapp"

# Authentication
JWT_SECRET="your-secret-key-here"
JWT_EXPIRES_IN="7d"

# External Services
STRIPE_PUBLIC_KEY="pk_test_..."
STRIPE_SECRET_KEY="sk_test_..."
SENDGRID_API_KEY="SG...."

# Monitoring
SENTRY_DSN="https://your-sentry-dsn"
```

## 🚀 Deployment Scripts

### Docker Deployment Script
```bash
#!/bin/bash
# deploy.sh - Production deployment script

set -e

echo "Starting deployment..."

# Build and tag images
docker build -t myapp:latest .
docker tag myapp:latest myregistry/myapp:$BUILD_NUMBER

# Push to registry
docker push myregistry/myapp:$BUILD_NUMBER

# Update Kubernetes deployment
kubectl set image deployment/myapp app=myregistry/myapp:$BUILD_NUMBER

# Wait for rollout to complete
kubectl rollout status deployment/myapp

echo "Deployment completed successfully!"
```

## 📋 Checklists

### Pre-Production Checklist
- [ ] SSL certificates configured
- [ ] Environment variables secured
- [ ] Database backups configured
- [ ] Monitoring and alerting set up
- [ ] Load testing completed
- [ ] Security scan passed
- [ ] Documentation updated
- [ ] Team trained on deployment process

### Performance Optimization Checklist
- [ ] Database queries optimized
- [ ] Caching layers implemented
- [ ] CDN configured for static assets
- [ ] Image optimization enabled
- [ ] Compression configured
- [ ] Performance monitoring active
- [ ] Load testing baseline established

---

**Usage**: Copy and modify these templates for your specific SaaS project needs. Always review and customize before using in production!