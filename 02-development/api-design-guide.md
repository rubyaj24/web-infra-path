# ![Swagger](../images/logos/swagger.svg) API Design Guide for SaaS Applications

![API Architecture](../images/api-architecture.png)
*RESTful API design patterns and best practices for scalable SaaS platforms*

## Overview

A well-designed API is the backbone of modern SaaS applications. This guide covers RESTful API design principles, authentication strategies, rate limiting, versioning, and documentation practices that ensure your API is scalable, secure, and easy to use.

## RESTful API Fundamentals

### HTTP Methods and Status Codes

#### Request Methods

```
GET    - Retrieve resource(s) - Safe, Idempotent
POST   - Create new resource - Not idempotent
PUT    - Replace entire resource - Idempotent
PATCH  - Partial update - Idempotent
DELETE - Remove resource - Idempotent
```

#### Status Codes

```
2xx - Success
  200 OK              - Request successful
  201 Created         - Resource created
  204 No Content      - Success, no response body
  
4xx - Client Error
  400 Bad Request     - Invalid request format
  401 Unauthorized    - Authentication required
  403 Forbidden       - Insufficient permissions
  404 Not Found       - Resource doesn't exist
  409 Conflict        - Resource conflict
  422 Unprocessable   - Validation failed
  429 Too Many        - Rate limit exceeded
  
5xx - Server Error
  500 Internal Error  - Server error
  503 Unavailable     - Service down
```

### API Endpoint Design

```
Base URL: https://api.example.com/v1

# Resource Collections
GET    /api/v1/users              - List all users
POST   /api/v1/users              - Create new user
GET    /api/v1/users/:id          - Get specific user
PUT    /api/v1/users/:id          - Replace user
PATCH  /api/v1/users/:id          - Update user fields
DELETE /api/v1/users/:id          - Delete user

# Nested Resources
GET    /api/v1/tenants/:id/users  - Get users for tenant
POST   /api/v1/tenants/:id/users  - Create user in tenant

# Query Parameters
GET    /api/v1/users?skip=0&limit=10              - Pagination
GET    /api/v1/users?sort=-created_at&status=active - Sorting & filtering
GET    /api/v1/users?fields=id,email,name        - Field selection
```

## Request and Response Format

### Standard Response Structure

```json
{
  "success": true,
  "data": {
    "id": "user-123",
    "email": "user@example.com",
    "name": "John Doe",
    "createdAt": "2025-12-06T10:30:00Z"
  },
  "meta": {
    "timestamp": "2025-12-06T10:30:00Z",
    "requestId": "req-abc123"
  }
}
```

### Error Response Structure

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      },
      {
        "field": "age",
        "message": "Must be at least 18"
      }
    ]
  },
  "meta": {
    "timestamp": "2025-12-06T10:30:00Z",
    "requestId": "req-abc123"
  }
}
```

### Paginated Response

```json
{
  "success": true,
  "data": [
    { "id": "user-1", "email": "user1@example.com" },
    { "id": "user-2", "email": "user2@example.com" }
  ],
  "pagination": {
    "total": 150,
    "limit": 10,
    "skip": 0,
    "pages": 15,
    "currentPage": 1,
    "hasNextPage": true,
    "hasPreviousPage": false
  },
  "meta": {
    "timestamp": "2025-12-06T10:30:00Z",
    "requestId": "req-abc123"
  }
}
```

## Authentication & Authorization

### JWT (JSON Web Token) Implementation

#### Token Structure

```
Header.Payload.Signature

Header:
{
  "alg": "HS256",
  "typ": "JWT"
}

Payload:
{
  "sub": "user-123",
  "email": "user@example.com",
  "tenantId": "tenant-456",
  "roles": ["admin", "editor"],
  "iat": 1702000000,
  "exp": 1702003600
}
```

#### Node.js JWT Implementation

```javascript
// middleware/auth.js
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRY = '1h';

// Generate JWT
export function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRY,
  });
}

// Verify JWT
export function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    throw new Error('Invalid or expired token');
  }
}

// Authentication middleware
export function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid authorization header',
      },
    });
  }
  
  const token = authHeader.slice(7);
  
  try {
    req.user = verifyToken(token);
    next();
  } catch (error) {
    res.status(401).json({
      success: false,
      error: {
        code: 'INVALID_TOKEN',
        message: error.message,
      },
    });
  }
}

// Role-based authorization
export function authorize(...allowedRoles) {
  return (req, res, next) => {
    const userRoles = req.user.roles || [];
    const hasRole = allowedRoles.some(role => userRoles.includes(role));
    
    if (!hasRole) {
      return res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'Insufficient permissions',
        },
      });
    }
    
    next();
  };
}
```

#### Python FastAPI Implementation

```python
# security.py
from datetime import datetime, timedelta
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthCredentials

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

security = HTTPBearer()

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def verify_token(credentials: HTTPAuthCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    return payload

def require_role(*allowed_roles: str):
    async def role_checker(payload: dict = Depends(verify_token)):
        user_roles = payload.get("roles", [])
        if not any(role in user_roles for role in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )
        return payload
    return role_checker
```

### OAuth 2.0 for Third-Party Integration

```javascript
// routes/oauth.js
import express from 'express';
import axios from 'axios';

const router = express.Router();

// Google OAuth callback
router.post('/auth/google', async (req, res) => {
  const { code, redirectUri } = req.body;
  
  try {
    // Exchange code for tokens
    const response = await axios.post('https://oauth2.googleapis.com/token', {
      code,
      client_id: process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.GOOGLE_CLIENT_SECRET,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    });
    
    const { access_token, id_token } = response.data;
    
    // Decode and verify ID token
    const googleUser = jwt.decode(id_token);
    
    // Find or create user
    let user = await User.findOne({ email: googleUser.email });
    if (!user) {
      user = await User.create({
        email: googleUser.email,
        name: googleUser.name,
        googleId: googleUser.sub,
        avatar: googleUser.picture,
      });
    }
    
    // Generate our JWT
    const token = generateToken({
      sub: user.id,
      email: user.email,
      roles: user.roles,
    });
    
    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
      },
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: {
        code: 'OAUTH_ERROR',
        message: error.message,
      },
    });
  }
});

export default router;
```

## Rate Limiting

### Token Bucket Algorithm

```javascript
// middleware/rateLimit.js
import Redis from 'redis';

const redis = Redis.createClient();

export async function rateLimitMiddleware(req, res, next) {
  const userId = req.user?.id || req.ip;
  const key = `rate_limit:${userId}`;
  
  try {
    const current = await redis.incr(key);
    
    if (current === 1) {
      // First request, set expiry
      await redis.expire(key, 60); // 1 minute window
    }
    
    const limit = 100; // 100 requests per minute
    res.set('X-RateLimit-Limit', limit);
    res.set('X-RateLimit-Remaining', Math.max(0, limit - current));
    
    if (current > limit) {
      return res.status(429).json({
        success: false,
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: `Rate limit exceeded. Maximum ${limit} requests per minute.`,
          retryAfter: 60,
        },
      });
    }
    
    next();
  } catch (error) {
    console.error('Rate limit error:', error);
    next(); // Don't block on error
  }
}
```

### Tiered Rate Limiting

```javascript
// Different limits for different tiers
const rateLimits = {
  free: 100,      // 100 requests/minute
  pro: 1000,      // 1000 requests/minute
  enterprise: -1, // unlimited
};

export async function tieredRateLimitMiddleware(req, res, next) {
  const user = req.user;
  const limit = rateLimits[user.plan] || rateLimits.free;
  
  if (limit === -1) {
    // Unlimited
    return next();
  }
  
  const key = `rate_limit:${user.id}`;
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, 60);
  }
  
  res.set('X-RateLimit-Limit', limit);
  res.set('X-RateLimit-Remaining', Math.max(0, limit - current));
  
  if (current > limit) {
    return res.status(429).json({
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: `Rate limit of ${limit} requests/minute exceeded`,
        retryAfter: 60,
      },
    });
  }
  
  next();
}
```

## API Versioning

### URL-Based Versioning (Recommended)

```
/api/v1/users    - Version 1
/api/v2/users    - Version 2
```

```javascript
// routes/index.js
import express from 'express';
import v1Router from './v1';
import v2Router from './v2';

const router = express.Router();

router.use('/v1', v1Router);
router.use('/v2', v2Router);

export default router;
```

### Backwards Compatibility

```javascript
// routes/v2/users.js
export async function getUser(req, res) {
  const user = await User.findById(req.params.id);
  
  // New response format for v2
  res.json({
    success: true,
    data: {
      id: user.id,
      email: user.email,
      profile: {
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
      },
      createdAt: user.createdAt,
    },
  });
}

// routes/v1/users.js
export async function getUser(req, res) {
  const user = await User.findById(req.params.id);
  
  // Legacy response format for v1
  res.json({
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    createdAt: user.createdAt,
  });
}
```

## OpenAPI/Swagger Documentation

### OpenAPI Specification (Express)

```javascript
// swagger.js
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'SaaS API',
      version: '1.0.0',
      description: 'Complete SaaS Platform API',
    },
    servers: [
      {
        url: 'http://localhost:3000/api',
        description: 'Development',
      },
      {
        url: 'https://api.example.com/api',
        description: 'Production',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
  },
  apis: ['./routes/**/*.js'],
};

const specs = swaggerJsdoc(options);

export function setupSwagger(app) {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs));
}
```

### API Documentation with Comments

```javascript
/**
 * @swagger
 * /users:
 *   get:
 *     summary: List all users
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: skip
 *         in: query
 *         type: integer
 *         default: 0
 *       - name: limit
 *         in: query
 *         type: integer
 *         default: 10
 *     responses:
 *       200:
 *         description: List of users
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *       401:
 *         description: Unauthorized
 */
router.get('/users', authMiddleware, getUserList);

/**
 * @swagger
 * /users:
 *   post:
 *     summary: Create a new user
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               name:
 *                 type: string
 *     responses:
 *       201:
 *         description: User created
 */
router.post('/users', authMiddleware, createUser);
```

## Input Validation

### Node.js with Joi

```javascript
// validators/userSchema.js
import Joi from 'joi';

export const createUserSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  firstName: Joi.string().max(100).required(),
  lastName: Joi.string().max(100).required(),
});

export const updateUserSchema = Joi.object({
  email: Joi.string().email(),
  firstName: Joi.string().max(100),
  lastName: Joi.string().max(100),
});

// middleware/validateRequest.js
export function validateRequest(schema) {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });
    
    if (error) {
      return res.status(422).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Validation failed',
          details: error.details.map(detail => ({
            field: detail.path.join('.'),
            message: detail.message,
          })),
        },
      });
    }
    
    req.validatedData = value;
    next();
  };
}

// routes/users.js
router.post('/users', 
  authMiddleware, 
  validateRequest(createUserSchema), 
  createUser
);
```

### Python with Pydantic

```python
# schemas.py
from pydantic import BaseModel, EmailStr, validator

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

class UserUpdate(BaseModel):
    email: EmailStr = None
    first_name: str = None
    last_name: str = None

# routes.py
@app.post("/users", response_model=UserResponse)
async def create_user(user_data: UserCreate):
    # Pydantic validates automatically
    user = await User.create(**user_data.dict())
    return user
```

## Pagination Best Practices

### Cursor-Based Pagination

```javascript
// Better for large datasets
export async function getUsersWithCursor(req, res) {
  const { cursor, limit = 10 } = req.query;
  
  let query = User.where({ tenantId: req.user.tenantId });
  
  if (cursor) {
    query = query.where('id', '>', cursor);
  }
  
  const users = await query.limit(limit + 1).exec();
  
  const hasMore = users.length > limit;
  if (hasMore) users.pop();
  
  const nextCursor = users.length > 0 ? users[users.length - 1].id : null;
  
  res.json({
    success: true,
    data: users,
    pagination: {
      hasMore,
      nextCursor,
    },
  });
}

// Usage: /api/users?cursor=user-123&limit=20
```

### Offset-Based Pagination

```javascript
// Simpler but less efficient for large datasets
export async function getUsersWithOffset(req, res) {
  const { skip = 0, limit = 10 } = req.query;
  
  const total = await User.countDocuments({ tenantId: req.user.tenantId });
  const users = await User.find({ tenantId: req.user.tenantId })
    .skip(skip)
    .limit(limit);
  
  res.json({
    success: true,
    data: users,
    pagination: {
      total,
      limit,
      skip,
      pages: Math.ceil(total / limit),
    },
  });
}

// Usage: /api/users?skip=0&limit=20
```

## CORS Configuration

```javascript
// middleware/cors.js
import cors from 'cors';

export const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
    
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 3600,
};

app.use(cors(corsOptions));
```

## Error Handling

### Centralized Error Handler

```javascript
// middleware/errorHandler.js
export function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || 500;
  const errorCode = err.code || 'INTERNAL_ERROR';
  
  console.error(`Error [${errorCode}]:`, err);
  
  res.status(statusCode).json({
    success: false,
    error: {
      code: errorCode,
      message: err.message || 'An error occurred',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    },
    meta: {
      timestamp: new Date().toISOString(),
      requestId: req.id,
    },
  });
}

// Custom error class
export class ApiError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}
```

## Sources and References

### Official Documentation
- [REST API Best Practices](https://restfulapi.net/) - RESTful API design guide
- [OpenAPI Specification](https://spec.openapis.org/) - API documentation standard
- [JWT Introduction](https://jwt.io/) - JSON Web Token reference
- [OAuth 2.0 Framework](https://tools.ietf.org/html/rfc6749) - Authorization protocol

### Tools & Libraries
- [Swagger/OpenAPI](https://swagger.io/) - API documentation
- [Postman](https://www.postman.com/) - API testing and collaboration
- [Express.js](https://expressjs.com/) - Node.js framework
- [FastAPI](https://fastapi.tiangolo.com/) - Python framework

### Best Practices Guides
- [Google API Design Guide](https://cloud.google.com/apis/design) - API design standards
- [Twilio API Best Practices](https://www.twilio.com/en-us/blog/api-best-practices) - Real-world examples
- [GitHub API Documentation](https://docs.github.com/en/rest) - Industry standard API

### Books
- "RESTful Web Services" by Leonard Richardson and Sam Ruby
- "Web API Design Best Practices" by Brian Mulloy
- "The Art of API Design" by Lukas Rosenstock

---

**Next:** [Frontend Development Guide](./frontend-development.md)
