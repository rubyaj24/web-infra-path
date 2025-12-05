# ![Node.js](../images/logos/express.svg) Backend Development Guide for SaaS Applications

![Backend Architecture](../images/backend-architecture.png)
*Modern backend architecture with microservices, API gateway, and database layers*

## Overview

Building a robust backend for SaaS applications requires careful consideration of scalability, security, performance, and maintainability. This guide covers modern backend development practices using Node.js and Python frameworks, with practical examples and best practices.

## Node.js Backend Development

### 1. Project Structure and Setup

![Node.js Project Structure](../images/nodejs-structure.png)

```
saas-backend/
├── src/
│   ├── config/           # Configuration files
│   │   ├── database.js
│   │   ├── redis.js
│   │   └── index.js
│   ├── controllers/      # Route handlers
│   │   ├── auth.controller.js
│   │   ├── user.controller.js
│   │   └── tenant.controller.js
│   ├── middleware/       # Custom middleware
│   │   ├── auth.middleware.js
│   │   ├── validation.middleware.js
│   │   └── tenant.middleware.js
│   ├── models/          # Database models
│   │   ├── User.js
│   │   ├── Tenant.js
│   │   └── index.js
│   ├── routes/          # API routes
│   │   ├── auth.routes.js
│   │   ├── user.routes.js
│   │   └── index.js
│   ├── services/        # Business logic
│   │   ├── auth.service.js
│   │   ├── user.service.js
│   │   └── email.service.js
│   ├── utils/           # Utility functions
│   │   ├── logger.js
│   │   ├── helpers.js
│   │   └── constants.js
│   └── app.js           # Express app setup
├── tests/               # Test files
├── docs/                # Documentation
├── package.json
└── .env.example
```

### 2. Express.js Application Setup

```javascript
// src/app.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');

const { errorHandler, notFoundHandler } = require('./middleware/error.middleware');
const routes = require('./routes');
const logger = require('./utils/logger');

const app = express();

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"]
        }
    },
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// CORS configuration
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-ID']
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression
app.use(compression());

// Logging
app.use(morgan('combined', {
    stream: {
        write: (message) => logger.info(message.trim())
    }
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000, // Limit each IP to 1000 requests per windowMs
    message: 'Too many requests from this IP, please try again later',
    standardHeaders: true,
    legacyHeaders: false
});
app.use('/api', limiter);

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version
    });
});

// API routes
app.use('/api/v1', routes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
```

### 3. Database Integration with Prisma

```javascript
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Tenant {
  id          String   @id @default(cuid())
  name        String
  slug        String   @unique
  planType    PlanType @default(BASIC)
  maxUsers    Int      @default(10)
  storageLimit Int     @default(5) // GB
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  users       User[]
  subscriptions Subscription[]
  
  @@map("tenants")
}

model User {
  id            String    @id @default(cuid())
  tenantId      String
  email         String
  passwordHash  String
  name          String
  role          UserRole  @default(USER)
  isActive      Boolean   @default(true)
  emailVerified Boolean   @default(false)
  lastLoginAt   DateTime?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
  
  tenant        Tenant    @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  
  @@unique([tenantId, email])
  @@map("users")
}

model Subscription {
  id                    String            @id @default(cuid())
  tenantId              String
  stripeSubscriptionId  String?           @unique
  planName              String
  status                SubscriptionStatus
  currentPeriodStart    DateTime
  currentPeriodEnd      DateTime
  createdAt             DateTime          @default(now())
  updatedAt             DateTime          @updatedAt
  
  tenant                Tenant            @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  
  @@map("subscriptions")
}

enum PlanType {
  BASIC
  PRO
  ENTERPRISE
}

enum UserRole {
  USER
  ADMIN
  SUPER_ADMIN
}

enum SubscriptionStatus {
  ACTIVE
  INACTIVE
  CANCELED
  PAST_DUE
}
```

### 4. Service Layer Implementation

```javascript
// src/services/user.service.js
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const AppError = require('../utils/AppError');

const prisma = new PrismaClient();

class UserService {
    async createUser(userData, tenantId) {
        const { email, password, name, role = 'USER' } = userData;

        // Check if user already exists
        const existingUser = await prisma.user.findUnique({
            where: {
                tenantId_email: {
                    tenantId,
                    email: email.toLowerCase()
                }
            }
        });

        if (existingUser) {
            throw new AppError('User with this email already exists', 409);
        }

        // Hash password
        const passwordHash = await bcrypt.hash(password, 12);

        // Create user
        const user = await prisma.user.create({
            data: {
                tenantId,
                email: email.toLowerCase(),
                passwordHash,
                name: name.trim(),
                role
            },
            select: {
                id: true,
                email: true,
                name: true,
                role: true,
                isActive: true,
                emailVerified: true,
                createdAt: true,
                tenant: {
                    select: {
                        id: true,
                        name: true,
                        slug: true
                    }
                }
            }
        });

        return user;
    }

    async getUserById(id, tenantId) {
        const user = await prisma.user.findFirst({
            where: {
                id,
                tenantId,
                isActive: true
            },
            select: {
                id: true,
                email: true,
                name: true,
                role: true,
                isActive: true,
                emailVerified: true,
                lastLoginAt: true,
                createdAt: true
            }
        });

        if (!user) {
            throw new AppError('User not found', 404);
        }

        return user;
    }

    async updateUser(id, updateData, tenantId) {
        const user = await prisma.user.findFirst({
            where: { id, tenantId }
        });

        if (!user) {
            throw new AppError('User not found', 404);
        }

        // Handle password update
        if (updateData.password) {
            updateData.passwordHash = await bcrypt.hash(updateData.password, 12);
            delete updateData.password;
        }

        // Handle email update
        if (updateData.email && updateData.email !== user.email) {
            const existingUser = await prisma.user.findUnique({
                where: {
                    tenantId_email: {
                        tenantId,
                        email: updateData.email.toLowerCase()
                    }
                }
            });

            if (existingUser) {
                throw new AppError('User with this email already exists', 409);
            }

            updateData.email = updateData.email.toLowerCase();
            updateData.emailVerified = false; // Require re-verification
        }

        const updatedUser = await prisma.user.update({
            where: { id },
            data: {
                ...updateData,
                updatedAt: new Date()
            },
            select: {
                id: true,
                email: true,
                name: true,
                role: true,
                isActive: true,
                emailVerified: true,
                updatedAt: true
            }
        });

        return updatedUser;
    }

    async deleteUser(id, tenantId) {
        const user = await prisma.user.findFirst({
            where: { id, tenantId }
        });

        if (!user) {
            throw new AppError('User not found', 404);
        }

        // Soft delete
        await prisma.user.update({
            where: { id },
            data: {
                isActive: false,
                email: `deleted_${Date.now()}_${user.email}` // Prevent email conflicts
            }
        });

        return true;
    }

    async findUsers(filters, tenantId) {
        const {
            page = 1,
            limit = 10,
            search,
            role,
            isActive = true,
            sortBy = 'createdAt',
            sortOrder = 'desc'
        } = filters;

        const skip = (page - 1) * limit;
        const orderBy = { [sortBy]: sortOrder };

        const where = {
            tenantId,
            ...(typeof isActive === 'boolean' && { isActive }),
            ...(role && { role }),
            ...(search && {
                OR: [
                    { name: { contains: search, mode: 'insensitive' } },
                    { email: { contains: search, mode: 'insensitive' } }
                ]
            })
        };

        const [users, total] = await Promise.all([
            prisma.user.findMany({
                where,
                select: {
                    id: true,
                    email: true,
                    name: true,
                    role: true,
                    isActive: true,
                    emailVerified: true,
                    lastLoginAt: true,
                    createdAt: true
                },
                orderBy,
                skip,
                take: limit
            }),
            prisma.user.count({ where })
        ]);

        return {
            data: users,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        };
    }

    async validatePassword(email, password, tenantId) {
        const user = await prisma.user.findUnique({
            where: {
                tenantId_email: {
                    tenantId,
                    email: email.toLowerCase()
                }
            },
            select: {
                id: true,
                passwordHash: true,
                isActive: true
            }
        });

        if (!user || !user.isActive) {
            return null;
        }

        const isValidPassword = await bcrypt.compare(password, user.passwordHash);
        return isValidPassword ? user.id : null;
    }
}

module.exports = new UserService();
```

## Python Backend Development (FastAPI)

### 1. Project Structure

```
saas-fastapi/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application
│   ├── config.py            # Configuration
│   ├── database.py          # Database connection
│   ├── dependencies.py      # Dependency injection
│   ├── api/                 # API routes
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── users.py
│   │   └── tenants.py
│   ├── models/              # SQLAlchemy models
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── tenant.py
│   ├── schemas/             # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── tenant.py
│   ├── services/            # Business logic
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   └── user_service.py
│   └── utils/               # Utilities
│       ├── __init__.py
│       ├── security.py
│       └── email.py
├── tests/
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

### 2. FastAPI Application Setup

```python
# app/main.py
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import time
import logging

from app.config import settings
from app.database import engine
from app.models import Base
from app.api import auth, users, tenants

# Create database tables
Base.metadata.create_all(bind=engine)

# Initialize FastAPI app
app = FastAPI(
    title="SaaS Platform API",
    description="Multi-tenant SaaS application backend",
    version="1.0.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_HOSTS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

# Request timing middleware
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

# Exception handlers
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "message": exc.detail,
                "status_code": exc.status_code
            },
            "timestamp": time.time()
        }
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "error": {
                "message": "Validation failed",
                "status_code": 422,
                "errors": exc.errors()
            },
            "timestamp": time.time()
        }
    )

# Health check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": time.time()
    }

# Include routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(tenants.router, prefix="/api/v1/tenants", tags=["Tenants"])
```

### 3. Database Models (SQLAlchemy)

```python
# app/models/user.py
from sqlalchemy import Boolean, Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.database import Base

class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    slug = Column(String(100), unique=True, nullable=False)
    plan_type = Column(String(50), default="basic")
    max_users = Column(Integer, default=10)
    storage_limit_gb = Column(Integer, default=5)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    users = relationship("User", back_populates="tenant", cascade="all, delete-orphan")

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    email = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    role = Column(String(50), default="user")
    is_active = Column(Boolean, default=True)
    email_verified = Column(Boolean, default=False)
    last_login_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    tenant = relationship("Tenant", back_populates="users")

    __table_args__ = (
        {"schema": None},  # You can add schema here if needed
    )
```

### 4. Pydantic Schemas

```python
# app/schemas/user.py
from pydantic import BaseModel, EmailStr, validator
from typing import Optional
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    USER = "user"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"

class UserBase(BaseModel):
    email: EmailStr
    name: str
    role: UserRole = UserRole.USER

class UserCreate(UserBase):
    password: str

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one digit')
        return v

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None

class UserInDB(UserBase):
    id: str
    tenant_id: str
    is_active: bool
    email_verified: bool
    last_login_at: Optional[datetime]
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        orm_mode = True

class UserResponse(BaseModel):
    success: bool = True
    data: UserInDB
    message: str = "Success"
    timestamp: datetime

class UsersListResponse(BaseModel):
    success: bool = True
    data: list[UserInDB]
    pagination: dict
    message: str = "Success"
    timestamp: datetime
```

### 5. Service Layer (Python)

```python
# app/services/user_service.py
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from typing import Optional, Dict, Any, List
from fastapi import HTTPException, status

from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.utils.security import get_password_hash, verify_password
import uuid

class UserService:
    def __init__(self, db: Session):
        self.db = db

    def create_user(self, user_data: UserCreate, tenant_id: str) -> User:
        # Check if user exists
        existing_user = self.db.query(User).filter(
            and_(
                User.tenant_id == tenant_id,
                User.email == user_data.email.lower()
            )
        ).first()

        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email already exists"
            )

        # Create user
        db_user = User(
            id=str(uuid.uuid4()),
            tenant_id=tenant_id,
            email=user_data.email.lower(),
            password_hash=get_password_hash(user_data.password),
            name=user_data.name.strip(),
            role=user_data.role.value
        )

        self.db.add(db_user)
        self.db.commit()
        self.db.refresh(db_user)

        return db_user

    def get_user_by_id(self, user_id: str, tenant_id: str) -> Optional[User]:
        return self.db.query(User).filter(
            and_(
                User.id == user_id,
                User.tenant_id == tenant_id,
                User.is_active == True
            )
        ).first()

    def update_user(self, user_id: str, user_update: UserUpdate, tenant_id: str) -> Optional[User]:
        user = self.get_user_by_id(user_id, tenant_id)
        if not user:
            return None

        update_data = user_update.dict(exclude_unset=True)

        # Handle email update
        if "email" in update_data:
            existing_user = self.db.query(User).filter(
                and_(
                    User.tenant_id == tenant_id,
                    User.email == update_data["email"].lower(),
                    User.id != user_id
                )
            ).first()

            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="User with this email already exists"
                )

            update_data["email"] = update_data["email"].lower()
            update_data["email_verified"] = False

        # Update user
        for field, value in update_data.items():
            setattr(user, field, value)

        self.db.commit()
        self.db.refresh(user)

        return user

    def delete_user(self, user_id: str, tenant_id: str) -> bool:
        user = self.get_user_by_id(user_id, tenant_id)
        if not user:
            return False

        # Soft delete
        user.is_active = False
        user.email = f"deleted_{int(time.time())}_{user.email}"

        self.db.commit()
        return True

    def get_users(
        self,
        tenant_id: str,
        page: int = 1,
        limit: int = 10,
        search: Optional[str] = None,
        role: Optional[str] = None,
        is_active: Optional[bool] = True
    ) -> Dict[str, Any]:
        
        query = self.db.query(User).filter(User.tenant_id == tenant_id)

        # Apply filters
        if is_active is not None:
            query = query.filter(User.is_active == is_active)

        if role:
            query = query.filter(User.role == role)

        if search:
            query = query.filter(
                or_(
                    User.name.ilike(f"%{search}%"),
                    User.email.ilike(f"%{search}%")
                )
            )

        # Get total count
        total = query.count()

        # Apply pagination
        offset = (page - 1) * limit
        users = query.offset(offset).limit(limit).all()

        return {
            "data": users,
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "pages": (total + limit - 1) // limit
            }
        }

    def authenticate_user(self, email: str, password: str, tenant_id: str) -> Optional[User]:
        user = self.db.query(User).filter(
            and_(
                User.tenant_id == tenant_id,
                User.email == email.lower(),
                User.is_active == True
            )
        ).first()

        if not user or not verify_password(password, user.password_hash):
            return None

        # Update last login
        user.last_login_at = datetime.utcnow()
        self.db.commit()

        return user
```

## Testing Backend Applications

### 1. Unit Testing (Jest for Node.js)

```javascript
// tests/unit/services/user.service.test.js
const UserService = require('../../../src/services/user.service');
const { PrismaClient } = require('@prisma/client');
const AppError = require('../../../src/utils/AppError');

// Mock Prisma
jest.mock('@prisma/client');
const mockPrisma = {
    user: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
    }
};

PrismaClient.mockImplementation(() => mockPrisma);

describe('UserService', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('createUser', () => {
        const mockTenantId = 'tenant-123';
        const userData = {
            email: 'test@example.com',
            password: 'TestPassword123!',
            name: 'Test User'
        };

        it('should create a user successfully', async () => {
            mockPrisma.user.findUnique.mockResolvedValue(null);
            mockPrisma.user.create.mockResolvedValue({
                id: 'user-123',
                email: userData.email,
                name: userData.name,
                role: 'USER'
            });

            const result = await UserService.createUser(userData, mockTenantId);

            expect(mockPrisma.user.findUnique).toHaveBeenCalledWith({
                where: {
                    tenantId_email: {
                        tenantId: mockTenantId,
                        email: userData.email.toLowerCase()
                    }
                }
            });

            expect(mockPrisma.user.create).toHaveBeenCalled();
            expect(result.email).toBe(userData.email);
        });

        it('should throw error if user already exists', async () => {
            mockPrisma.user.findUnique.mockResolvedValue({ id: 'existing-user' });

            await expect(
                UserService.createUser(userData, mockTenantId)
            ).rejects.toThrow(AppError);
        });
    });
});
```

### 2. Integration Testing (pytest for Python)

```python
# tests/test_users.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import get_db, Base
from app.config import settings

# Test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

class TestUsers:
    def setup_method(self):
        """Set up test data before each test"""
        # Create test tenant and user
        self.tenant_data = {
            "name": "Test Tenant",
            "slug": "test-tenant"
        }
        
        tenant_response = client.post("/api/v1/tenants", json=self.tenant_data)
        self.tenant_id = tenant_response.json()["data"]["id"]
        
        # Get auth token
        auth_response = client.post("/api/v1/auth/login", json={
            "email": "admin@test.com",
            "password": "TestPassword123!"
        })
        self.auth_token = auth_response.json()["data"]["token"]
        self.headers = {"Authorization": f"Bearer {self.auth_token}"}

    def test_create_user(self):
        """Test user creation"""
        user_data = {
            "name": "Test User",
            "email": "test@example.com",
            "password": "TestPassword123!",
            "role": "user"
        }

        response = client.post(
            "/api/v1/users",
            json=user_data,
            headers=self.headers
        )

        assert response.status_code == 201
        data = response.json()
        assert data["success"] is True
        assert data["data"]["email"] == user_data["email"]
        assert "password" not in data["data"]

    def test_get_users(self):
        """Test user listing"""
        response = client.get("/api/v1/users", headers=self.headers)

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert "pagination" in data

    def test_create_user_duplicate_email(self):
        """Test creating user with duplicate email"""
        user_data = {
            "name": "Test User",
            "email": "duplicate@example.com",
            "password": "TestPassword123!"
        }

        # Create first user
        client.post("/api/v1/users", json=user_data, headers=self.headers)
        
        # Try to create duplicate
        response = client.post(
            "/api/v1/users",
            json=user_data,
            headers=self.headers
        )

        assert response.status_code == 409
        assert "already exists" in response.json()["error"]["message"]

    def test_unauthorized_access(self):
        """Test unauthorized access"""
        response = client.get("/api/v1/users")
        assert response.status_code == 401
```

## Performance Optimization

### 1. Database Query Optimization

```javascript
// Optimized database queries with proper indexing
class UserService {
    async getUsersWithStats(tenantId, filters) {
        // Use database-level aggregation instead of application-level
        const query = `
            SELECT 
                u.*,
                COUNT(CASE WHEN ul.created_at >= NOW() - INTERVAL '30 days' THEN 1 END) as recent_logins,
                COUNT(up.id) as total_projects
            FROM users u
            LEFT JOIN user_logins ul ON ul.user_id = u.id
            LEFT JOIN user_projects up ON up.user_id = u.id
            WHERE u.tenant_id = $1 AND u.is_active = TRUE
            GROUP BY u.id
            ORDER BY u.created_at DESC
            LIMIT $2 OFFSET $3
        `;

        return await this.db.query(query, [tenantId, filters.limit, filters.offset]);
    }

    // Use connection pooling and prepared statements
    async bulkCreateUsers(usersData, tenantId) {
        const values = usersData.map(user => [
            user.id,
            tenantId,
            user.email,
            user.passwordHash,
            user.name,
            user.role
        ]);

        const query = `
            INSERT INTO users (id, tenant_id, email, password_hash, name, role)
            VALUES ${values.map((_, i) => `($${i * 6 + 1}, $${i * 6 + 2}, $${i * 6 + 3}, $${i * 6 + 4}, $${i * 6 + 5}, $${i * 6 + 6})`).join(', ')}
            ON CONFLICT (tenant_id, email) DO NOTHING
            RETURNING id, email, name
        `;

        return await this.db.query(query, values.flat());
    }
}
```

### 2. Caching Strategies

```javascript
// Redis caching implementation
const Redis = require('redis');
const redis = Redis.createClient(process.env.REDIS_URL);

class CacheService {
    constructor() {
        this.defaultTTL = 3600; // 1 hour
    }

    generateKey(prefix, ...args) {
        return `${prefix}:${args.join(':')}`;
    }

    async get(key) {
        try {
            const data = await redis.get(key);
            return data ? JSON.parse(data) : null;
        } catch (error) {
            console.error('Cache get error:', error);
            return null;
        }
    }

    async set(key, data, ttl = this.defaultTTL) {
        try {
            await redis.setEx(key, ttl, JSON.stringify(data));
            return true;
        } catch (error) {
            console.error('Cache set error:', error);
            return false;
        }
    }

    async delete(pattern) {
        try {
            const keys = await redis.keys(pattern);
            if (keys.length > 0) {
                await redis.del(keys);
            }
            return true;
        } catch (error) {
            console.error('Cache delete error:', error);
            return false;
        }
    }
}

// Usage in service
class UserService {
    constructor() {
        this.cache = new CacheService();
    }

    async getUserById(id, tenantId) {
        const cacheKey = this.cache.generateKey('user', tenantId, id);
        
        // Try cache first
        let user = await this.cache.get(cacheKey);
        if (user) {
            return user;
        }

        // Get from database
        user = await prisma.user.findFirst({
            where: { id, tenantId, isActive: true }
        });

        if (user) {
            // Cache for 15 minutes
            await this.cache.set(cacheKey, user, 900);
        }

        return user;
    }

    async updateUser(id, updateData, tenantId) {
        const user = await this.updateUserInDb(id, updateData, tenantId);
        
        if (user) {
            // Invalidate cache
            const cacheKey = this.cache.generateKey('user', tenantId, id);
            await this.cache.delete(cacheKey);
            
            // Invalidate related caches
            await this.cache.delete(`users:${tenantId}:*`);
        }

        return user;
    }
}
```

## Sources and References

### Official Documentation
- [Node.js Documentation](https://nodejs.org/en/docs/) - Official Node.js documentation
- [Express.js Guide](https://expressjs.com/en/guide/) - Express.js official guide
- [FastAPI Documentation](https://fastapi.tiangolo.com/) - FastAPI official documentation
- [Prisma Documentation](https://www.prisma.io/docs/) - Modern database toolkit

### Best Practices Guides
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices) - Comprehensive Node.js best practices
- [12-Factor App Methodology](https://12factor.net/) - Modern app development principles
- [SQLAlchemy Best Practices](https://docs.sqlalchemy.org/en/14/orm/tutorial.html) - Python ORM guide

### Books
- "Node.js Design Patterns" by Mario Casciaro
- "FastAPI Modern APIs with Python" by Bill Lubanovic
- "Effective SQL" by John Viescas, Douglas Steele, and Ben Clothier

### Tools and Resources
- [Postman](https://www.postman.com/) - API development and testing
- [Prisma Studio](https://www.prisma.io/studio) - Database GUI
- [Redis](https://redis.io/) - In-memory data structure store
- [Docker](https://www.docker.com/) - Containerization platform

---

**Next:** [Docker Fundamentals Guide](../03-devops-infrastructure/docker-beginner-guide.md)