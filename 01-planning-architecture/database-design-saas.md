# ![PostgreSQL](../images/logos/postgresql.svg) Database Design for SaaS Applications

![Database Architecture](../images/database-architecture.png)
*Multi-tenant database architecture patterns for SaaS applications*

## Overview

Database design is crucial for SaaS applications as it directly impacts scalability, performance, and data isolation between tenants. This guide covers the essential patterns and best practices for designing databases that can handle multi-tenancy effectively.

## Multi-Tenant Database Patterns

### 1. Single Database, Single Schema (Row-Level Security)

![Single Database Single Schema](../images/single-db-single-schema.png)

**Description**: All tenants share the same database and schema, with tenant isolation achieved through row-level security using a tenant identifier column.

```sql
-- Example table structure
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for efficient tenant queries
CREATE INDEX idx_users_tenant_id ON users(tenant_id);

-- Row Level Security (PostgreSQL)
CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

**Pros:**
- Simple to implement and maintain
- Cost-effective for many small tenants
- Easy database migrations
- Shared resources and efficient storage

**Cons:**
- Risk of data leakage if not implemented correctly
- Limited customization per tenant
- Performance impact with large datasets
- Complex queries due to tenant filtering

**Best For:** Small to medium SaaS with similar tenant requirements

### 2. Single Database, Multiple Schemas

![Single Database Multiple Schemas](../images/single-db-multiple-schemas.png)

**Description**: Each tenant has its own schema within a shared database instance.

```sql
-- Create tenant-specific schemas
CREATE SCHEMA tenant_abc123;
CREATE SCHEMA tenant_def456;

-- Create tables in each schema
CREATE TABLE tenant_abc123.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Application connection logic
const getSchemaName = (tenantId) => `tenant_${tenantId}`;
const query = `SELECT * FROM ${getSchemaName(tenantId)}.users`;
```

**Pros:**
- Better data isolation than single schema
- Tenant-specific customizations possible
- Easier to backup individual tenants
- Better performance than row-level filtering

**Cons:**
- More complex application logic
- Schema management complexity
- Limited by database connection limits
- Migration complexity increases

**Best For:** Medium-sized SaaS with tenant-specific customizations

### 3. Multiple Databases (Database per Tenant)

![Multiple Databases](../images/multiple-databases.png)

**Description**: Each tenant has a completely separate database instance.

```javascript
// Database connection management
class DatabaseManager {
    constructor() {
        this.connections = new Map();
    }

    async getConnection(tenantId) {
        if (!this.connections.has(tenantId)) {
            const connection = await createConnection({
                host: process.env.DB_HOST,
                database: `tenant_${tenantId}`,
                username: process.env.DB_USER,
                password: process.env.DB_PASS,
            });
            this.connections.set(tenantId, connection);
        }
        return this.connections.get(tenantId);
    }
}
```

**Pros:**
- Maximum data isolation and security
- Tenant-specific performance tuning
- Easy tenant data backup and restore
- No "noisy neighbor" problems

**Cons:**
- Highest operational complexity
- Higher infrastructure costs
- Complex cross-tenant reporting
- Resource underutilization for small tenants

**Best For:** Enterprise SaaS with strict compliance requirements

## Database Schema Design Best Practices

### 1. Core Entity Design

```sql
-- Tenant entity
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan_type VARCHAR(50) NOT NULL DEFAULT 'basic',
    max_users INTEGER DEFAULT 10,
    storage_limit_gb INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- User entity with tenant relationship
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(tenant_id, email)
);

-- Subscription tracking
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    stripe_subscription_id VARCHAR(255) UNIQUE,
    plan_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    current_period_start TIMESTAMP NOT NULL,
    current_period_end TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 2. Indexing Strategy

```sql
-- Primary indexes for performance
CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);

-- Composite indexes for common queries
CREATE INDEX idx_subscriptions_tenant_status ON subscriptions(tenant_id, status);
CREATE INDEX idx_users_tenant_role ON users(tenant_id, role) WHERE is_active = TRUE;

-- Partial indexes for specific use cases
CREATE INDEX idx_active_users ON users(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_recent_logins ON users(tenant_id, last_login_at) 
    WHERE last_login_at > NOW() - INTERVAL '30 days';
```

### 3. Data Migration Patterns

```sql
-- Migration script template
-- Migration: 001_add_user_preferences.sql

-- Add new column with default value
ALTER TABLE users 
ADD COLUMN preferences JSONB DEFAULT '{}';

-- Update existing rows if needed
UPDATE users 
SET preferences = '{"theme": "light", "notifications": true}'
WHERE preferences IS NULL;

-- Add constraint after data update
ALTER TABLE users 
ALTER COLUMN preferences SET NOT NULL;

-- Add index for JSON queries
CREATE INDEX idx_users_preferences ON users USING GIN (preferences);
```

## Performance Optimization

### Query Optimization

![Query Performance](../images/query-optimization.png)

```sql
-- Bad: Missing tenant filtering
SELECT * FROM orders WHERE status = 'pending';

-- Good: Always include tenant filtering
SELECT * FROM orders 
WHERE tenant_id = $1 AND status = 'pending'
ORDER BY created_at DESC
LIMIT 20;

-- Optimized with covering index
CREATE INDEX idx_orders_tenant_status_created 
ON orders(tenant_id, status, created_at DESC)
INCLUDE (id, total_amount, customer_name);
```

### Connection Pooling

```javascript
// PostgreSQL connection pool configuration
const pool = new Pool({
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    port: 5432,
    max: 20, // Maximum pool size
    min: 5,  // Minimum pool size
    idle: 10000, // Close idle connections after 10s
    connect_timeout: 60, // Connection timeout
    acquire_timeout: 60000, // Pool acquire timeout
    timeout: 60000, // Query timeout
});

// Usage with tenant context
const getUsersForTenant = async (tenantId, page = 1, limit = 10) => {
    const offset = (page - 1) * limit;
    const query = `
        SELECT id, email, name, role, created_at
        FROM users 
        WHERE tenant_id = $1 AND is_active = TRUE
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [tenantId, limit, offset]);
    return result.rows;
};
```

## Data Security and Compliance

### Encryption at Rest

```sql
-- Enable transparent data encryption (PostgreSQL)
-- Configure in postgresql.conf
cluster_name = 'main'
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'

-- Column-level encryption for sensitive data
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive columns
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    ssn_encrypted BYTEA, -- Encrypted SSN
    credit_card_encrypted BYTEA, -- Encrypted credit card
    created_at TIMESTAMP DEFAULT NOW()
);

-- Encryption functions
CREATE OR REPLACE FUNCTION encrypt_data(data TEXT, key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, key);
END;
$$ LANGUAGE plpgsql;
```

### Audit Logging

```sql
-- Audit log table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    changed_at TIMESTAMP DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- Trigger function for audit logging
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (tenant_id, table_name, operation, old_values)
        VALUES (OLD.tenant_id, TG_TABLE_NAME, TG_OP, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (tenant_id, table_name, operation, old_values, new_values)
        VALUES (NEW.tenant_id, TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (tenant_id, table_name, operation, new_values)
        VALUES (NEW.tenant_id, TG_TABLE_NAME, TG_OP, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

## Backup and Recovery Strategies

![Backup Strategy](../images/backup-recovery.png)

### Automated Backup Scripts

```bash
#!/bin/bash
# backup-database.sh - Automated database backup script

# Configuration
DB_HOST="localhost"
DB_NAME="saas_prod"
DB_USER="backup_user"
BACKUP_DIR="/backups/postgresql"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

# Create backup directory if not exists
mkdir -p "${BACKUP_DIR}"

# Perform backup
echo "Starting backup of ${DB_NAME}..."
pg_dump -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" \
    --verbose --clean --create --format=custom \
    | gzip > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: ${BACKUP_FILE}"
    
    # Upload to cloud storage (AWS S3)
    aws s3 cp "${BACKUP_FILE}" "s3://saas-backups/postgresql/"
    
    # Clean up local old backups
    find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    
    echo "Backup process completed successfully"
else
    echo "Backup failed!"
    exit 1
fi
```

### Point-in-Time Recovery Setup

```bash
# PostgreSQL WAL-E configuration for continuous archiving
# In postgresql.conf:
archive_mode = on
archive_command = 'wal-e wal-push %p'
archive_timeout = 60

# Base backup command
wal-e backup-push /var/lib/postgresql/data

# Recovery command (when needed)
wal-e backup-fetch /var/lib/postgresql/data LATEST
```

## Monitoring and Alerting

### Database Performance Metrics

```sql
-- Query to monitor slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    (total_time / calls) as avg_time_ms,
    stddev_time
FROM pg_stat_statements 
WHERE mean_time > 100 -- queries taking more than 100ms on average
ORDER BY mean_time DESC
LIMIT 20;

-- Monitor database connections
SELECT 
    datname,
    state,
    count(*) as connection_count
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY datname, state
ORDER BY connection_count DESC;

-- Check table sizes and bloat
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Sources and References

### Official Documentation
- [PostgreSQL Multi-tenancy](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) - Row Level Security documentation
- [MySQL Multi-tenancy Guide](https://dev.mysql.com/doc/refman/8.0/en/partitioning.html) - Partitioning for multi-tenancy
- [MongoDB Multi-tenancy Patterns](https://docs.mongodb.com/manual/tutorial/model-data-for-schema-design/) - Document-based multi-tenancy

### Best Practices Articles
- [AWS Multi-tenant SaaS Database Strategies](https://docs.aws.amazon.com/wellarchitected/latest/saas-lens/database-strategies.html)
- [Microsoft Azure Multi-tenant Applications](https://docs.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
- [Google Cloud Multi-tenancy Best Practices](https://cloud.google.com/architecture/multi-tenant-saas-patterns)

### Books
- "Designing Data-Intensive Applications" by Martin Kleppmann
- "Building Multi-Tenant Applications with Django" by Nathan Friedly
- "PostgreSQL: Up and Running" by Regina Obe and Leo Hsu

### Tools and Resources
- [dbdiagram.io](https://dbdiagram.io) - Database relationship diagrams
- [PostgreSQL Explain Visualizer](https://tatiyants.com/pev/) - Query performance analysis
- [DataGrip](https://www.jetbrains.com/datagrip/) - Database IDE
- [Postico](https://eggerapps.at/postico/) - PostgreSQL client for macOS

---

**Next:** [API Design Best Practices](./api-design-guide.md)