# API Design Best Practices for SaaS Applications

![API Architecture](../images/api-architecture.png)
*RESTful API architecture with authentication and rate limiting*

## Overview

Well-designed APIs are the backbone of modern SaaS applications. This guide covers REST API design principles, authentication strategies, documentation practices, and scaling considerations specifically for multi-tenant SaaS platforms.

## RESTful API Design Principles

### 1. Resource-Based URL Structure

![REST URL Structure](../images/rest-url-structure.png)

```http
# Good: Resource-based URLs
GET    /api/v1/tenants/{tenant_id}/users
POST   /api/v1/tenants/{tenant_id}/users
GET    /api/v1/tenants/{tenant_id}/users/{user_id}
PUT    /api/v1/tenants/{tenant_id}/users/{user_id}
DELETE /api/v1/tenants/{tenant_id}/users/{user_id}

# Bad: Action-based URLs
GET    /api/v1/getAllUsers
POST   /api/v1/createUser
GET    /api/v1/getUserById?id=123
```

### 2. HTTP Methods and Status Codes

```javascript
// User management endpoints
class UserController {
    // GET /api/v1/users - List users
    async listUsers(req, res) {
        try {
            const { page = 1, limit = 10, search } = req.query;
            const users = await userService.findUsers({
                tenantId: req.tenant.id,
                page: parseInt(page),
                limit: parseInt(limit),
                search
            });

            res.status(200).json({
                data: users.data,
                pagination: {
                    page: users.page,
                    limit: users.limit,
                    total: users.total,
                    pages: Math.ceil(users.total / users.limit)
                }
            });
        } catch (error) {
            res.status(500).json({
                error: 'Internal server error',
                message: error.message
            });
        }
    }

    // POST /api/v1/users - Create user
    async createUser(req, res) {
        try {
            const userData = {
                ...req.body,
                tenantId: req.tenant.id
            };

            const user = await userService.createUser(userData);
            
            res.status(201).json({
                data: user,
                message: 'User created successfully'
            });
        } catch (error) {
            if (error.code === 'DUPLICATE_EMAIL') {
                return res.status(409).json({
                    error: 'Conflict',
                    message: 'User with this email already exists'
                });
            }
            
            res.status(400).json({
                error: 'Bad request',
                message: error.message
            });
        }
    }

    // PUT /api/v1/users/{id} - Update user
    async updateUser(req, res) {
        try {
            const { id } = req.params;
            const user = await userService.updateUser(id, req.body, req.tenant.id);
            
            if (!user) {
                return res.status(404).json({
                    error: 'Not found',
                    message: 'User not found'
                });
            }

            res.status(200).json({
                data: user,
                message: 'User updated successfully'
            });
        } catch (error) {
            res.status(400).json({
                error: 'Bad request',
                message: error.message
            });
        }
    }

    // DELETE /api/v1/users/{id} - Delete user
    async deleteUser(req, res) {
        try {
            const { id } = req.params;
            const deleted = await userService.deleteUser(id, req.tenant.id);
            
            if (!deleted) {
                return res.status(404).json({
                    error: 'Not found',
                    message: 'User not found'
                });
            }

            res.status(204).send();
        } catch (error) {
            res.status(400).json({
                error: 'Bad request',
                message: error.message
            });
        }
    }
}
```

### 3. Standard Response Format

```javascript
// Consistent API response structure
class ApiResponse {
    static success(data, message = 'Success', meta = {}) {
        return {
            success: true,
            data,
            message,
            meta,
            timestamp: new Date().toISOString()
        };
    }

    static error(message, errors = [], statusCode = 400) {
        return {
            success: false,
            error: {
                message,
                statusCode,
                errors
            },
            timestamp: new Date().toISOString()
        };
    }

    static paginated(data, pagination, message = 'Success') {
        return {
            success: true,
            data,
            message,
            pagination: {
                page: pagination.page,
                limit: pagination.limit,
                total: pagination.total,
                pages: Math.ceil(pagination.total / pagination.limit),
                hasNext: pagination.page < Math.ceil(pagination.total / pagination.limit),
                hasPrev: pagination.page > 1
            },
            timestamp: new Date().toISOString()
        };
    }
}

// Usage in controllers
app.get('/api/v1/users', async (req, res) => {
    const users = await userService.findUsers(req.query);
    res.json(ApiResponse.paginated(users.data, users.pagination));
});
```

## Authentication and Authorization

### 1. JWT-Based Authentication

![JWT Authentication Flow](../images/jwt-auth-flow.png)

```javascript
// JWT authentication middleware
const jwt = require('jsonwebtoken');
const { promisify } = require('util');

class AuthMiddleware {
    static async authenticate(req, res, next) {
        try {
            // Extract token from header
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                return res.status(401).json({
                    error: 'Unauthorized',
                    message: 'Access token required'
                });
            }

            const token = authHeader.substring(7);
            
            // Verify token
            const decoded = await promisify(jwt.verify)(token, process.env.JWT_SECRET);
            
            // Load user and tenant information
            const user = await User.findById(decoded.userId).populate('tenant');
            if (!user || !user.isActive) {
                return res.status(401).json({
                    error: 'Unauthorized',
                    message: 'Invalid or expired token'
                });
            }

            // Attach to request
            req.user = user;
            req.tenant = user.tenant;
            
            next();
        } catch (error) {
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Invalid token'
            });
        }
    }

    static authorize(roles = []) {
        return (req, res, next) => {
            if (!req.user) {
                return res.status(401).json({
                    error: 'Unauthorized',
                    message: 'Authentication required'
                });
            }

            if (roles.length && !roles.includes(req.user.role)) {
                return res.status(403).json({
                    error: 'Forbidden',
                    message: 'Insufficient permissions'
                });
            }

            next();
        };
    }
}

// Usage
app.get('/api/v1/admin/users', 
    AuthMiddleware.authenticate,
    AuthMiddleware.authorize(['admin', 'super_admin']),
    userController.listUsers
);
```

### 2. OAuth 2.0 Integration

```javascript
// OAuth 2.0 integration with Google
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;

passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: "/api/v1/auth/google/callback"
}, async (accessToken, refreshToken, profile, done) => {
    try {
        // Check if user exists
        let user = await User.findOne({ 
            $or: [
                { googleId: profile.id },
                { email: profile.emails[0].value }
            ]
        });

        if (user) {
            // Update Google ID if not set
            if (!user.googleId) {
                user.googleId = profile.id;
                await user.save();
            }
            return done(null, user);
        }

        // Create new user
        user = await User.create({
            googleId: profile.id,
            name: profile.displayName,
            email: profile.emails[0].value,
            avatar: profile.photos[0].value,
            emailVerified: true
        });

        done(null, user);
    } catch (error) {
        done(error, null);
    }
}));

// OAuth routes
app.get('/api/v1/auth/google',
    passport.authenticate('google', { scope: ['profile', 'email'] })
);

app.get('/api/v1/auth/google/callback',
    passport.authenticate('google', { session: false }),
    (req, res) => {
        // Generate JWT token
        const token = jwt.sign(
            { userId: req.user.id, tenantId: req.user.tenantId },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        // Redirect to frontend with token
        res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${token}`);
    }
);
```

## Rate Limiting and Throttling

![Rate Limiting](../images/rate-limiting.png)

### 1. Express Rate Limiting

```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

// Redis client for distributed rate limiting
const redisClient = redis.createClient({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT
});

// Different rate limits for different endpoints
const createRateLimiter = (windowMs, max, message) => {
    return rateLimit({
        store: new RedisStore({
            client: redisClient,
            prefix: 'rl:'
        }),
        windowMs,
        max,
        message: {
            error: 'Too many requests',
            message,
            retryAfter: Math.ceil(windowMs / 1000)
        },
        standardHeaders: true,
        legacyHeaders: false,
        keyGenerator: (req) => {
            // Rate limit per tenant and user
            return `${req.tenant?.id || 'anonymous'}:${req.ip}`;
        }
    });
};

// Apply different limits
app.use('/api/v1/auth/login', createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    5, // 5 attempts
    'Too many login attempts, please try again later'
));

app.use('/api/v1', createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    1000, // 1000 requests
    'Too many requests from this tenant'
));
```

### 2. Tenant-Based Rate Limiting

```javascript
// Advanced tenant-based rate limiting
class TenantRateLimiter {
    constructor() {
        this.limits = {
            'basic': { rpm: 100, rph: 1000 },
            'pro': { rpm: 500, rph: 10000 },
            'enterprise': { rpm: 2000, rph: 50000 }
        };
    }

    middleware() {
        return async (req, res, next) => {
            if (!req.tenant) {
                return res.status(401).json({
                    error: 'Unauthorized',
                    message: 'Tenant identification required'
                });
            }

            const planLimits = this.limits[req.tenant.planType] || this.limits['basic'];
            const key = `rate_limit:${req.tenant.id}`;
            
            try {
                // Check current usage
                const current = await redisClient.multi()
                    .incr(`${key}:minute`)
                    .expire(`${key}:minute`, 60)
                    .incr(`${key}:hour`)
                    .expire(`${key}:hour`, 3600)
                    .exec();

                const minuteCount = current[0][1];
                const hourCount = current[2][1];

                // Check limits
                if (minuteCount > planLimits.rpm) {
                    return res.status(429).json({
                        error: 'Rate limit exceeded',
                        message: `Minute rate limit exceeded (${planLimits.rpm} requests per minute)`,
                        retryAfter: 60
                    });
                }

                if (hourCount > planLimits.rph) {
                    return res.status(429).json({
                        error: 'Rate limit exceeded',
                        message: `Hourly rate limit exceeded (${planLimits.rph} requests per hour)`,
                        retryAfter: 3600
                    });
                }

                // Add headers
                res.set({
                    'X-RateLimit-Limit-Minute': planLimits.rpm,
                    'X-RateLimit-Remaining-Minute': Math.max(0, planLimits.rpm - minuteCount),
                    'X-RateLimit-Limit-Hour': planLimits.rph,
                    'X-RateLimit-Remaining-Hour': Math.max(0, planLimits.rph - hourCount)
                });

                next();
            } catch (error) {
                console.error('Rate limiting error:', error);
                next(); // Continue on rate limiter error
            }
        };
    }
}
```

## Input Validation and Sanitization

### 1. Request Validation with Joi

```javascript
const Joi = require('joi');

// Validation schemas
const userSchemas = {
    create: Joi.object({
        name: Joi.string().min(2).max(100).required(),
        email: Joi.string().email().required(),
        password: Joi.string().min(8).pattern(
            /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/
        ).required().messages({
            'string.pattern.base': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
        }),
        role: Joi.string().valid('user', 'admin').default('user'),
        metadata: Joi.object().optional()
    }),

    update: Joi.object({
        name: Joi.string().min(2).max(100).optional(),
        email: Joi.string().email().optional(),
        role: Joi.string().valid('user', 'admin').optional(),
        isActive: Joi.boolean().optional(),
        metadata: Joi.object().optional()
    }),

    query: Joi.object({
        page: Joi.number().integer().min(1).default(1),
        limit: Joi.number().integer().min(1).max(100).default(10),
        search: Joi.string().max(100).optional(),
        role: Joi.string().valid('user', 'admin').optional(),
        isActive: Joi.boolean().optional(),
        sortBy: Joi.string().valid('name', 'email', 'createdAt').default('createdAt'),
        sortOrder: Joi.string().valid('asc', 'desc').default('desc')
    })
};

// Validation middleware
const validate = (schema, property = 'body') => {
    return (req, res, next) => {
        const { error, value } = schema.validate(req[property], {
            abortEarly: false,
            stripUnknown: true
        });

        if (error) {
            const errors = error.details.map(detail => ({
                field: detail.path.join('.'),
                message: detail.message
            }));

            return res.status(400).json({
                error: 'Validation failed',
                errors
            });
        }

        req[property] = value;
        next();
    };
};

// Usage
app.post('/api/v1/users',
    validate(userSchemas.create),
    userController.createUser
);

app.get('/api/v1/users',
    validate(userSchemas.query, 'query'),
    userController.listUsers
);
```

### 2. SQL Injection Prevention

```javascript
// Using parameterized queries (safe)
const getUsersForTenant = async (tenantId, filters) => {
    let query = `
        SELECT id, name, email, role, created_at 
        FROM users 
        WHERE tenant_id = $1 AND is_active = TRUE
    `;
    const params = [tenantId];
    let paramIndex = 2;

    // Safely add filters
    if (filters.search) {
        query += ` AND (name ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`;
        params.push(`%${filters.search}%`);
        paramIndex++;
    }

    if (filters.role) {
        query += ` AND role = $${paramIndex}`;
        params.push(filters.role);
        paramIndex++;
    }

    // Safe sorting with whitelist
    const allowedSortFields = ['name', 'email', 'created_at'];
    const sortBy = allowedSortFields.includes(filters.sortBy) ? filters.sortBy : 'created_at';
    const sortOrder = filters.sortOrder === 'asc' ? 'ASC' : 'DESC';
    query += ` ORDER BY ${sortBy} ${sortOrder}`;

    query += ` LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(filters.limit, (filters.page - 1) * filters.limit);

    const result = await db.query(query, params);
    return result.rows;
};
```

## API Versioning

### 1. URL Versioning

```javascript
// Version-specific routes
const express = require('express');
const v1Router = require('./routes/v1');
const v2Router = require('./routes/v2');

app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);

// Version compatibility middleware
const versionCompatibility = (req, res, next) => {
    const version = req.baseUrl.split('/')[2]; // Extract version from URL
    
    // Add version-specific behavior
    req.apiVersion = version;
    
    // Handle deprecated features
    if (version === 'v1' && req.path.includes('/deprecated-endpoint')) {
        res.set('Warning', '299 - "This endpoint is deprecated. Please use v2"');
    }
    
    next();
};

app.use('/api/:version', versionCompatibility);
```

### 2. Header-Based Versioning

```javascript
// Header-based version detection
const getApiVersion = (req) => {
    const acceptHeader = req.headers.accept;
    const versionMatch = acceptHeader?.match(/application\/vnd\.myapi\.v(\d+)\+json/);
    return versionMatch ? `v${versionMatch[1]}` : 'v1'; // Default to v1
};

const versionMiddleware = (req, res, next) => {
    req.apiVersion = getApiVersion(req);
    next();
};

// Version-specific controllers
const userControllerV1 = require('./controllers/v1/users');
const userControllerV2 = require('./controllers/v2/users');

app.get('/api/users', versionMiddleware, (req, res, next) => {
    if (req.apiVersion === 'v2') {
        return userControllerV2.listUsers(req, res, next);
    }
    return userControllerV1.listUsers(req, res, next);
});
```

## OpenAPI Documentation

### 1. Swagger/OpenAPI Specification

```yaml
# swagger.yaml
openapi: 3.0.0
info:
  title: SaaS Platform API
  version: 1.0.0
  description: RESTful API for multi-tenant SaaS platform
  contact:
    name: API Support
    email: support@myapi.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.myapp.com/v1
    description: Production server
  - url: https://staging-api.myapp.com/v1
    description: Staging server

security:
  - BearerAuth: []

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    User:
      type: object
      required:
        - id
        - name
        - email
        - tenantId
      properties:
        id:
          type: string
          format: uuid
          example: "123e4567-e89b-12d3-a456-426614174000"
        name:
          type: string
          minLength: 2
          maxLength: 100
          example: "John Doe"
        email:
          type: string
          format: email
          example: "john@example.com"
        role:
          type: string
          enum: [user, admin]
          example: "user"
        tenantId:
          type: string
          format: uuid
        isActive:
          type: boolean
          example: true
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time

    CreateUserRequest:
      type: object
      required:
        - name
        - email
        - password
      properties:
        name:
          type: string
          minLength: 2
          maxLength: 100
        email:
          type: string
          format: email
        password:
          type: string
          minLength: 8
        role:
          type: string
          enum: [user, admin]
          default: user

    ApiResponse:
      type: object
      properties:
        success:
          type: boolean
        data:
          type: object
        message:
          type: string
        timestamp:
          type: string
          format: date-time

    ErrorResponse:
      type: object
      properties:
        success:
          type: boolean
          example: false
        error:
          type: object
          properties:
            message:
              type: string
            statusCode:
              type: integer
            errors:
              type: array
              items:
                type: object

paths:
  /users:
    get:
      summary: List users
      description: Retrieve a paginated list of users for the authenticated tenant
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 10
        - name: search
          in: query
          schema:
            type: string
            maxLength: 100
      responses:
        '200':
          description: Users retrieved successfully
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ApiResponse'
                  - type: object
                    properties:
                      data:
                        type: array
                        items:
                          $ref: '#/components/schemas/User'
                      pagination:
                        type: object

    post:
      summary: Create user
      description: Create a new user for the authenticated tenant
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
      responses:
        '201':
          description: User created successfully
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/ApiResponse'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/User'
        '400':
          description: Bad request
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '409':
          description: User already exists
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
```

### 2. Automated Documentation Generation

```javascript
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

// Swagger configuration
const swaggerOptions = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'SaaS Platform API',
            version: '1.0.0',
            description: 'RESTful API for multi-tenant SaaS platform'
        },
        servers: [
            {
                url: process.env.API_BASE_URL || 'http://localhost:3000/api/v1'
            }
        ]
    },
    apis: ['./routes/*.js', './models/*.js']
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Serve documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: "SaaS API Documentation"
}));

// JSDoc comments in route files
/**
 * @swagger
 * /users:
 *   get:
 *     summary: List users
 *     tags: [Users]
 *     security:
 *       - BearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Page number
 *     responses:
 *       200:
 *         description: Users retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 */
app.get('/users', userController.listUsers);
```

## Error Handling

### 1. Centralized Error Handler

```javascript
// Custom error classes
class AppError extends Error {
    constructor(message, statusCode = 500, code = null) {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.isOperational = true;
        
        Error.captureStackTrace(this, this.constructor);
    }
}

class ValidationError extends AppError {
    constructor(errors) {
        super('Validation failed', 400, 'VALIDATION_ERROR');
        this.errors = errors;
    }
}

class NotFoundError extends AppError {
    constructor(resource = 'Resource') {
        super(`${resource} not found`, 404, 'NOT_FOUND');
    }
}

// Global error handler middleware
const errorHandler = (error, req, res, next) => {
    let err = { ...error };
    err.message = error.message;

    // Log error
    console.error(error);

    // Mongoose validation error
    if (error.name === 'ValidationError') {
        const errors = Object.values(error.errors).map(val => ({
            field: val.path,
            message: val.message
        }));
        err = new ValidationError(errors);
    }

    // Mongoose duplicate key error
    if (error.code === 11000) {
        const field = Object.keys(error.keyValue)[0];
        err = new AppError(`${field} already exists`, 409, 'DUPLICATE_ENTRY');
    }

    // JWT errors
    if (error.name === 'JsonWebTokenError') {
        err = new AppError('Invalid token', 401, 'INVALID_TOKEN');
    }

    if (error.name === 'TokenExpiredError') {
        err = new AppError('Token expired', 401, 'TOKEN_EXPIRED');
    }

    res.status(err.statusCode || 500).json({
        success: false,
        error: {
            message: err.message || 'Internal server error',
            code: err.code,
            ...(err.errors && { errors: err.errors }),
            ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
        },
        timestamp: new Date().toISOString()
    });
};

// 404 handler
const notFoundHandler = (req, res, next) => {
    const error = new NotFoundError(`Route ${req.originalUrl}`);
    next(error);
};

app.use(notFoundHandler);
app.use(errorHandler);
```

## API Testing

### 1. Automated Testing with Jest and Supertest

```javascript
// tests/api/users.test.js
const request = require('supertest');
const app = require('../../app');
const { setupDatabase, cleanupDatabase } = require('../helpers/database');

describe('Users API', () => {
    let authToken;
    let testUser;
    let tenant;

    beforeAll(async () => {
        await setupDatabase();
        
        // Create test tenant and user
        tenant = await createTestTenant();
        testUser = await createTestUser(tenant.id);
        
        // Get auth token
        const loginResponse = await request(app)
            .post('/api/v1/auth/login')
            .send({
                email: testUser.email,
                password: 'TestPassword123!'
            });
        
        authToken = loginResponse.body.data.token;
    });

    afterAll(async () => {
        await cleanupDatabase();
    });

    describe('GET /api/v1/users', () => {
        it('should list users for authenticated tenant', async () => {
            const response = await request(app)
                .get('/api/v1/users')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.success).toBe(true);
            expect(Array.isArray(response.body.data)).toBe(true);
            expect(response.body.pagination).toBeDefined();
        });

        it('should filter users by search query', async () => {
            const response = await request(app)
                .get('/api/v1/users?search=test')
                .set('Authorization', `Bearer ${authToken}`)
                .expect(200);

            expect(response.body.data.every(user => 
                user.name.toLowerCase().includes('test') || 
                user.email.toLowerCase().includes('test')
            )).toBe(true);
        });

        it('should return 401 without authentication', async () => {
            await request(app)
                .get('/api/v1/users')
                .expect(401);
        });
    });

    describe('POST /api/v1/users', () => {
        it('should create a new user', async () => {
            const userData = {
                name: 'New User',
                email: 'newuser@example.com',
                password: 'NewPassword123!'
            };

            const response = await request(app)
                .post('/api/v1/users')
                .set('Authorization', `Bearer ${authToken}`)
                .send(userData)
                .expect(201);

            expect(response.body.success).toBe(true);
            expect(response.body.data.name).toBe(userData.name);
            expect(response.body.data.email).toBe(userData.email);
            expect(response.body.data.password).toBeUndefined();
        });

        it('should validate required fields', async () => {
            const response = await request(app)
                .post('/api/v1/users')
                .set('Authorization', `Bearer ${authToken}`)
                .send({})
                .expect(400);

            expect(response.body.success).toBe(false);
            expect(response.body.error.errors).toBeDefined();
        });

        it('should prevent duplicate emails', async () => {
            const userData = {
                name: 'Duplicate User',
                email: testUser.email,
                password: 'Password123!'
            };

            const response = await request(app)
                .post('/api/v1/users')
                .set('Authorization', `Bearer ${authToken}`)
                .send(userData)
                .expect(409);

            expect(response.body.error.message).toContain('already exists');
        });
    });
});
```

## Sources and References

### Official Documentation
- [REST API Design Standards](https://restfulapi.net/) - Comprehensive REST API design guide
- [OpenAPI Specification](https://swagger.io/specification/) - Official OpenAPI/Swagger documentation
- [JWT.io](https://jwt.io/) - JSON Web Token documentation and debugging
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749) - Official OAuth 2.0 specification

### Best Practices Guides
- [Microsoft REST API Guidelines](https://github.com/Microsoft/api-guidelines) - Microsoft's API design standards
- [Google API Design Guide](https://cloud.google.com/apis/design) - Google's API design principles
- [Stripe API Documentation](https://stripe.com/docs/api) - Example of excellent API documentation

### Books
- "RESTful Web APIs" by Leonard Richardson and Mike Amundsen
- "Building APIs with Node.js" by Caio Ribeiro Pereira
- "API Security in Action" by Neil Madden

### Tools and Resources
- [Postman](https://www.postman.com/) - API development and testing platform
- [Insomnia](https://insomnia.rest/) - REST and GraphQL client
- [Swagger Editor](https://editor.swagger.io/) - Online OpenAPI editor
- [JSON Schema](https://json-schema.org/) - JSON data validation

---

**Next:** [Backend Development Guide](../02-development/backend-development-guide.md)