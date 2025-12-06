# ![PostgreSQL](../images/logos/postgresql.svg) Database Integration Guide for SaaS Applications

![Database Integration](../images/database-integration.png)
*Connecting your backend application to databases with best practices and optimization*

## Overview

Database integration is a critical component of SaaS development. This guide covers connecting Node.js and Python applications to various databases, implementing connection pooling, managing migrations, and applying performance optimization techniques essential for production SaaS applications.

## Prerequisites

- Basic understanding of SQL and databases
- Node.js 16+ or Python 3.8+ installed
- PostgreSQL, MySQL, or MongoDB server running
- Understanding of environment variables and configuration management

## Node.js Database Integration

### 1. PostgreSQL with Prisma

Prisma is the recommended ORM for Node.js SaaS applications due to its type safety and excellent migrations support.

#### Installation

```bash
npm install @prisma/client
npm install -D prisma

# Initialize Prisma
npx prisma init
```

#### Configuration (.env)

```env
DATABASE_URL="postgresql://user:password@localhost:5432/saas_app?schema=public"
POSTGRES_USER=saas_user
POSTGRES_PASSWORD=secure_password
POSTGRES_DB=saas_app
```

#### Schema Definition (prisma/schema.prisma)

```prisma
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model Tenant {
  id        String   @id @default(cuid())
  name      String   @unique
  slug      String   @unique
  status    String   @default("active")
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  users     User[]
  workspaces Workspace[]
  
  @@map("tenants")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  firstName String?
  lastName  String?
  role      String   @default("user")
  
  tenantId  String
  tenant    Tenant   @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([tenantId])
  @@map("users")
}

model Workspace {
  id        String   @id @default(cuid())
  name      String
  description String?
  
  tenantId  String
  tenant    Tenant   @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([tenantId])
  @@map("workspaces")
}
```

#### Migrations

```bash
# Create a new migration
npx prisma migrate dev --name init

# Apply migrations in production
npx prisma migrate deploy

# View migration status
npx prisma migrate status

# Reset database (development only)
npx prisma migrate reset
```

#### Usage in Application

```javascript
// lib/prisma.js - Singleton pattern for connection pooling
import { PrismaClient } from '@prisma/client';

const globalForPrisma = global;

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

```javascript
// services/userService.js
import { prisma } from '../lib/prisma';

class UserService {
  // Get user by ID with tenant context
  async getUserById(userId, tenantId) {
    return prisma.user.findFirst({
      where: {
        id: userId,
        tenantId: tenantId, // Ensure tenant isolation
      },
      include: {
        tenant: true,
      },
    });
  }

  // Create user with transaction
  async createUser(userData, tenantId) {
    return prisma.user.create({
      data: {
        ...userData,
        tenantId,
      },
    });
  }

  // Batch operations with transaction
  async createUsersInBatch(users, tenantId) {
    return prisma.$transaction(
      users.map((user) =>
        prisma.user.create({
          data: {
            ...user,
            tenantId,
          },
        })
      )
    );
  }

  // Complex query with relations
  async getTenantWithStats(tenantId) {
    return prisma.tenant.findUnique({
      where: { id: tenantId },
      include: {
        users: {
          select: {
            id: true,
            email: true,
            role: true,
          },
        },
        workspaces: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });
  }
}

export default new UserService();
```

### 2. MySQL with Sequelize

```bash
npm install sequelize mysql2
npm install -D sequelize-cli
```

#### Configuration

```javascript
// config/database.js
module.exports = {
  development: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: 'mysql',
    logging: false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000,
    },
  },
  production: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: 'mysql',
    logging: false,
    pool: {
      max: 20,
      min: 5,
      acquire: 30000,
      idle: 10000,
    },
  },
};
```

#### Model Definition

```javascript
// models/User.js
module.exports = (sequelize, DataTypes) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    tenantId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
  }, {
    tableName: 'users',
    timestamps: true,
  });

  User.associate = (models) => {
    User.belongsTo(models.Tenant, {
      foreignKey: 'tenantId',
      onDelete: 'CASCADE',
    });
  };

  return User;
};
```

### 3. MongoDB with Mongoose

```bash
npm install mongoose
```

#### Schema Definition

```javascript
// models/User.js
import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  password: {
    type: String,
    required: true,
    select: false, // Don't return by default
  },
  firstName: String,
  lastName: String,
  role: {
    type: String,
    enum: ['admin', 'user'],
    default: 'user',
  },
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  lastLogin: Date,
}, {
  timestamps: true,
  collection: 'users',
});

// Indexes for performance
userSchema.index({ tenantId: 1, email: 1 });
userSchema.index({ email: 1 });

// Middleware to enforce tenant isolation
userSchema.query.forTenant = function(tenantId) {
  return this.where({ tenantId });
};

// Virtual for full name
userSchema.virtual('fullName').get(function() {
  return `${this.firstName} ${this.lastName}`;
});

export const User = mongoose.model('User', userSchema);
```

#### Connection Management

```javascript
// lib/mongoConnection.js
import mongoose from 'mongoose';

let cachedConnection = null;

export async function connectToDatabase() {
  if (cachedConnection) {
    return cachedConnection;
  }

  const connection = await mongoose.connect(process.env.MONGODB_URI, {
    maxPoolSize: 10,
    minPoolSize: 5,
    socketTimeoutMS: 45000,
  });

  cachedConnection = connection;
  return connection;
}
```

## Python Database Integration

### 1. PostgreSQL with SQLAlchemy

```bash
pip install sqlalchemy psycopg2-binary python-dotenv
```

#### Configuration

```python
# config/database.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import QueuePool

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@localhost:5432/saas_app"
)

# Connection pooling for production
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,  # Test connections before using
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

#### Model Definition

```python
# models/user.py
from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from config.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password = Column(String(255), nullable=False)
    first_name = Column(String(100))
    last_name = Column(String(100))
    role = Column(String(50), default="user")
    
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    tenant = relationship("Tenant", back_populates="users")
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index('ix_users_tenant_email', 'tenant_id', 'email'),
    )
```

#### Usage with FastAPI

```python
# services/user_service.py
from sqlalchemy.orm import Session
from models.user import User
from schemas.user import UserCreate

class UserService:
    @staticmethod
    def get_user_by_email(db: Session, email: str, tenant_id: str):
        return db.query(User).filter(
            User.email == email,
            User.tenant_id == tenant_id
        ).first()
    
    @staticmethod
    def create_user(db: Session, user_data: UserCreate, tenant_id: str):
        db_user = User(
            email=user_data.email,
            password=user_data.password,  # Hash in production!
            tenant_id=tenant_id,
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    
    @staticmethod
    def get_users_for_tenant(db: Session, tenant_id: str, skip: int = 0, limit: int = 100):
        return db.query(User).filter(
            User.tenant_id == tenant_id
        ).offset(skip).limit(limit).all()
```

### 2. MongoDB with PyMongo

```bash
pip install pymongo motor
```

#### Configuration

```python
# config/mongodb.py
import asyncio
from motor.motor_asyncio import AsyncClient, AsyncDatabase
import os

MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "saas_app")

class MongoDB:
    client: AsyncClient = None
    db: AsyncDatabase = None

mongodb = MongoDB()

async def connect_to_mongo():
    mongodb.client = AsyncClient(
        MONGODB_URL,
        maxPoolSize=10,
        minPoolSize=5,
    )
    mongodb.db = mongodb.client[DB_NAME]
    print("Connected to MongoDB")

async def close_mongo_connection():
    mongodb.client.close()
    print("Closed MongoDB connection")
```

#### Collections and Operations

```python
# services/user_service.py
from config.mongodb import mongodb
from bson import ObjectId

class UserService:
    @staticmethod
    async def create_user(user_data: dict, tenant_id: str):
        user_collection = mongodb.db["users"]
        user_data["tenant_id"] = ObjectId(tenant_id)
        result = await user_collection.insert_one(user_data)
        return str(result.inserted_id)
    
    @staticmethod
    async def get_user(user_id: str, tenant_id: str):
        user_collection = mongodb.db["users"]
        user = await user_collection.find_one({
            "_id": ObjectId(user_id),
            "tenant_id": ObjectId(tenant_id),
        })
        return user
    
    @staticmethod
    async def get_users_for_tenant(tenant_id: str, skip: int = 0, limit: int = 100):
        user_collection = mongodb.db["users"]
        cursor = user_collection.find({
            "tenant_id": ObjectId(tenant_id)
        }).skip(skip).limit(limit)
        
        users = []
        async for user in cursor:
            users.append(user)
        return users
```

## Connection Pooling Best Practices

### Node.js Connection Pooling

```javascript
// Example with custom connection pool management
class DatabasePool {
  constructor(maxConnections = 20) {
    this.maxConnections = maxConnections;
    this.activeConnections = 0;
    this.waitingQueue = [];
  }

  async acquireConnection() {
    if (this.activeConnections < this.maxConnections) {
      this.activeConnections++;
      return new Promise((resolve) => resolve(true));
    }
    
    return new Promise((resolve) => {
      this.waitingQueue.push(() => {
        this.activeConnections++;
        resolve(true);
      });
    });
  }

  releaseConnection() {
    this.activeConnections--;
    
    if (this.waitingQueue.length > 0) {
      const nextWaiter = this.waitingQueue.shift();
      nextWaiter();
    }
  }
}
```

### Python Connection Pooling

```python
# config/database.py - Already configured above
# For additional fine-tuning:

from sqlalchemy import event
from sqlalchemy.pool import Pool

# Log pool checkouts
@event.listens_for(Pool, "connect")
def receive_connect(dbapi_conn, connection_record):
    print(f"Pool connection: {dbapi_conn}")

@event.listens_for(Pool, "checkout")
def receive_checkout(dbapi_conn, connection_record, connection_proxy):
    print(f"Pool checkout: {dbapi_conn}")

@event.listens_for(Pool, "checkin")
def receive_checkin(dbapi_conn, connection_record):
    print(f"Pool checkin: {dbapi_conn}")
```

## Migrations Management

### Database Versioning

```sql
-- migrations/001_initial_schema.sql
CREATE TABLE schema_versions (
    id SERIAL PRIMARY KEY,
    version INT NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL,
    installed_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time INT -- milliseconds
);

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_users_email_tenant ON users(email, tenant_id);
CREATE INDEX idx_users_tenant ON users(tenant_id);

INSERT INTO schema_versions (version, description, execution_time) 
VALUES (1, 'Initial schema', 0);
```

### Running Migrations

```bash
# Prisma
npx prisma migrate dev

# Sequelize
npx sequelize-cli db:migrate

# Manual SQL
psql -U user -d saas_app -f migrations/001_initial_schema.sql
```

## Performance Optimization

### Query Optimization

```javascript
// ❌ Bad: N+1 query problem
const users = await prisma.user.findMany();
for (let user of users) {
  const tenant = await prisma.tenant.findUnique({
    where: { id: user.tenantId }
  });
}

// ✅ Good: Use include to fetch relations
const users = await prisma.user.findMany({
  include: {
    tenant: true,
  },
});
```

### Indexing Strategy

```sql
-- Create indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);

-- For full-text search
CREATE INDEX idx_users_name_search ON users USING GIN(
  to_tsvector('english', first_name || ' ' || last_name)
);
```

### Caching with Redis

```javascript
// services/userService.js
import redis from '../lib/redis';
import { prisma } from '../lib/prisma';

class UserService {
  async getUserById(userId, tenantId) {
    const cacheKey = `user:${tenantId}:${userId}`;
    
    // Check cache first
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
    
    // Fetch from database
    const user = await prisma.user.findFirst({
      where: { id: userId, tenantId },
    });
    
    // Cache for 1 hour
    if (user) {
      await redis.setex(cacheKey, 3600, JSON.stringify(user));
    }
    
    return user;
  }
  
  async invalidateUserCache(userId, tenantId) {
    const cacheKey = `user:${tenantId}:${userId}`;
    await redis.del(cacheKey);
  }
}
```

## Sources and References

### Official Documentation
- [Prisma Documentation](https://www.prisma.io/docs/) - Modern database toolkit for Node.js
- [Sequelize Documentation](https://sequelize.org/) - Promise-based ORM for Node.js
- [Mongoose Documentation](https://mongoosejs.com/) - MongoDB object modeling
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/) - Python SQL toolkit
- [Motor Documentation](https://motor.readthedocs.io/) - Async MongoDB driver

### Best Practices
- [Database Connection Pooling](https://use-the-index-luke.com/) - SQL performance optimization
- [PostgreSQL Performance](https://wiki.postgresql.org/wiki/Performance_Optimization) - PostgreSQL tuning
- [MongoDB Best Practices](https://docs.mongodb.com/manual/administration/production-checklist/) - Production deployment

### Books
- "Database Reliability Engineering" by Laine Campbell and Charity Majors
- "Designing Data-Intensive Applications" by Martin Kleppmann
- "High Performance MySQL" by Brendan Gregg and others

---

**Next:** [API Design Best Practices](./api-design-guide.md)
