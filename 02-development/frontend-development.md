# ![React](../images/logos/react.svg) Frontend Development Guide for SaaS Applications

![Frontend Architecture](../images/frontend-architecture.png)
*Modern responsive frontend development with React, Vue, and best practices for SaaS UIs*

## Overview

Building an effective frontend for SaaS applications requires more than just UI components. This guide covers component architecture, state management, performance optimization, authentication flows, and responsive design patterns essential for creating scalable, maintainable SaaS interfaces.

## Frontend Fundamentals

### Project Structure

```
src/
├── components/
│   ├── common/           # Reusable components
│   │   ├── Button.jsx
│   │   ├── Modal.jsx
│   │   └── Header.jsx
│   ├── features/         # Feature-specific components
│   │   ├── Auth/
│   │   ├── Dashboard/
│   │   └── Users/
│   └── layouts/
│       ├── MainLayout.jsx
│       └── AuthLayout.jsx
├── hooks/                # Custom React hooks
│   ├── useAuth.js
│   ├── useFetch.js
│   └── useLocalStorage.js
├── services/             # API and external services
│   ├── api.js
│   ├── authService.js
│   └── userService.js
├── store/                # State management
│   ├── authSlice.js
│   └── userSlice.js
├── styles/               # Global styles
│   ├── globals.css
│   └── variables.css
├── utils/                # Helper functions
│   ├── validators.js
│   ├── formatters.js
│   └── constants.js
└── pages/                # Page components
    ├── LoginPage.jsx
    ├── DashboardPage.jsx
    └── NotFoundPage.jsx
```

## React Best Practices

### Component Architecture

#### Functional Components with Hooks

```jsx
// components/features/UserList.jsx
import React, { useState, useEffect } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { userService } from '../../services/userService';
import UserCard from './UserCard';

const UserList = ({ tenantId }) => {
  const { token } = useAuth();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        setLoading(true);
        const response = await userService.getUsersByTenant(tenantId, {
          headers: { Authorization: `Bearer ${token}` }
        });
        setUsers(response.data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchUsers();
  }, [tenantId, token]);

  if (loading) return <div>Loading users...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="user-list">
      <h2>Users</h2>
      <div className="grid">
        {users.map(user => (
          <UserCard key={user.id} user={user} />
        ))}
      </div>
    </div>
  );
};

export default UserList;
```

#### Custom Hooks

```jsx
// hooks/useAuth.js
import { useCallback } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { setUser, setToken, clearAuth } from '../store/authSlice';
import { authService } from '../services/authService';

export function useAuth() {
  const dispatch = useDispatch();
  const { user, token } = useSelector(state => state.auth);

  const login = useCallback(async (email, password) => {
    try {
      const response = await authService.login(email, password);
      dispatch(setToken(response.token));
      dispatch(setUser(response.user));
      return response;
    } catch (error) {
      throw error;
    }
  }, [dispatch]);

  const logout = useCallback(() => {
    dispatch(clearAuth());
    localStorage.removeItem('token');
  }, [dispatch]);

  const signup = useCallback(async (userData) => {
    try {
      const response = await authService.signup(userData);
      dispatch(setToken(response.token));
      dispatch(setUser(response.user));
      return response;
    } catch (error) {
      throw error;
    }
  }, [dispatch]);

  return {
    user,
    token,
    isAuthenticated: !!token,
    login,
    logout,
    signup,
  };
}

// hooks/useFetch.js
import { useState, useEffect } from 'react';

export function useFetch(url, options = {}) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const response = await fetch(url, options);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const result = await response.json();
        setData(result);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [url, options]);

  return { data, loading, error };
}
```

### State Management with Redux

```javascript
// store/authSlice.js
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';

export const loginAsync = createAsyncThunk(
  'auth/login',
  async ({ email, password }, { rejectWithValue }) => {
    try {
      const response = await fetch('/api/v1/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      if (!response.ok) throw new Error('Login failed');
      return response.json();
    } catch (error) {
      return rejectWithValue(error.message);
    }
  }
);

const authSlice = createSlice({
  name: 'auth',
  initialState: {
    user: null,
    token: localStorage.getItem('token'),
    loading: false,
    error: null,
  },
  reducers: {
    setUser: (state, action) => {
      state.user = action.payload;
    },
    setToken: (state, action) => {
      state.token = action.payload;
      localStorage.setItem('token', action.payload);
    },
    clearAuth: (state) => {
      state.user = null;
      state.token = null;
      localStorage.removeItem('token');
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loginAsync.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(loginAsync.fulfilled, (state, action) => {
        state.loading = false;
        state.user = action.payload.user;
        state.token = action.payload.token;
        localStorage.setItem('token', action.payload.token);
      })
      .addCase(loginAsync.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
      });
  },
});

export const { setUser, setToken, clearAuth } = authSlice.actions;
export default authSlice.reducer;
```

### Protected Routes

```jsx
// components/ProtectedRoute.jsx
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const ProtectedRoute = ({ children, requiredRole = null }) => {
  const { isAuthenticated, user } = useAuth();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (requiredRole && !user?.roles?.includes(requiredRole)) {
    return <Navigate to="/unauthorized" replace />;
  }

  return children;
};

export default ProtectedRoute;
```

## Vue.js Development

### Component Structure

```vue
<!-- components/UserProfile.vue -->
<template>
  <div class="user-profile">
    <div v-if="loading" class="loading">Loading...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else class="profile">
      <img :src="user.avatar" :alt="user.name" class="avatar" />
      <h2>{{ user.firstName }} {{ user.lastName }}</h2>
      <p>{{ user.email }}</p>
      <button @click="editProfile">Edit Profile</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useAuth } from '@/composables/useAuth';
import { userService } from '@/services/userService';

const props = defineProps({
  userId: String,
});

const emit = defineEmits(['profile-updated']);

const { token } = useAuth();
const user = ref(null);
const loading = ref(true);
const error = ref(null);

const fetchUser = async () => {
  try {
    loading.value = true;
    const response = await userService.getUserById(props.userId, {
      headers: { Authorization: `Bearer ${token.value}` }
    });
    user.value = response.data;
  } catch (err) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};

const editProfile = () => {
  // Handle edit
};

onMounted(fetchUser);
</script>

<style scoped>
.user-profile {
  padding: 2rem;
}

.avatar {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  object-fit: cover;
}

.profile {
  text-align: center;
}

button {
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  background: #0056b3;
}
</style>
```

### State Management with Pinia

```javascript
// stores/auth.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { authService } from '@/services/authService';

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null);
  const token = ref(localStorage.getItem('token'));
  const loading = ref(false);
  const error = ref(null);

  const isAuthenticated = computed(() => !!token.value);

  const login = async (email, password) => {
    try {
      loading.value = true;
      error.value = null;
      const response = await authService.login(email, password);
      token.value = response.token;
      user.value = response.user;
      localStorage.setItem('token', response.token);
      return response;
    } catch (err) {
      error.value = err.message;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const logout = () => {
    user.value = null;
    token.value = null;
    localStorage.removeItem('token');
  };

  return {
    user,
    token,
    loading,
    error,
    isAuthenticated,
    login,
    logout,
  };
});
```

## Forms and Validation

### React Form Handling

```jsx
// components/LoginForm.jsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { validateEmail, validatePassword } from '../utils/validators';

const LoginForm = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [formData, setFormData] = useState({
    email: '',
    password: '',
  });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const validateForm = () => {
    const newErrors = {};
    
    if (!validateEmail(formData.email)) {
      newErrors.email = 'Invalid email address';
    }
    if (!validatePassword(formData.password)) {
      newErrors.password = 'Password must be at least 8 characters';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    try {
      setLoading(true);
      await login(formData.email, formData.password);
      navigate('/dashboard');
    } catch (error) {
      setErrors({ submit: error.message });
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="login-form">
      <div className="form-group">
        <label htmlFor="email">Email</label>
        <input
          type="email"
          id="email"
          name="email"
          value={formData.email}
          onChange={handleChange}
          className={errors.email ? 'input-error' : ''}
        />
        {errors.email && <span className="error-text">{errors.email}</span>}
      </div>

      <div className="form-group">
        <label htmlFor="password">Password</label>
        <input
          type="password"
          id="password"
          name="password"
          value={formData.password}
          onChange={handleChange}
          className={errors.password ? 'input-error' : ''}
        />
        {errors.password && <span className="error-text">{errors.password}</span>}
      </div>

      {errors.submit && <div className="alert-error">{errors.submit}</div>}

      <button type="submit" disabled={loading}>
        {loading ? 'Signing in...' : 'Sign In'}
      </button>
    </form>
  );
};

export default LoginForm;
```

## Responsive Design

### Mobile-First Approach

```css
/* styles/responsive.css */

/* Base styles (mobile) */
.container {
  width: 100%;
  padding: 1rem;
}

.grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

.card {
  padding: 1rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* Tablet */
@media (min-width: 768px) {
  .container {
    max-width: 750px;
    margin: 0 auto;
  }

  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .container {
    max-width: 1200px;
  }

  .grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

/* Large Desktop */
@media (min-width: 1440px) {
  .container {
    max-width: 1400px;
  }

  .grid {
    grid-template-columns: repeat(4, 1fr);
  }
}
```

## Performance Optimization

### Code Splitting

```jsx
// App.jsx
import React, { Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';

const Dashboard = lazy(() => import('./pages/DashboardPage'));
const Users = lazy(() => import('./pages/UsersPage'));
const Settings = lazy(() => import('./pages/SettingsPage'));

function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<div>Loading...</div>}>
        <Routes>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/users" element={<Users />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}

export default App;
```

### Image Optimization

```jsx
// components/OptimizedImage.jsx
import React from 'react';

const OptimizedImage = ({ src, alt, width, height }) => {
  return (
    <picture>
      <source 
        srcSet={`${src.replace(/\.(\w+)$/, '-small.$1')} 320w, ${src} 1280w`}
        media="(max-width: 640px)"
      />
      <img 
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading="lazy"
      />
    </picture>
  );
};

export default OptimizedImage;
```

### Memoization

```jsx
// Prevent unnecessary re-renders
import React, { memo, useCallback } from 'react';

const UserCard = memo(({ user, onDelete }) => {
  return (
    <div className="card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </div>
  );
});

const UserList = ({ users }) => {
  const handleDelete = useCallback((userId) => {
    // Handle delete
  }, []);

  return (
    <div className="list">
      {users.map(user => (
        <UserCard key={user.id} user={user} onDelete={handleDelete} />
      ))}
    </div>
  );
};

export default UserList;
```

## Testing Frontend Code

### Unit Testing with Jest

```javascript
// components/__tests__/Button.test.js
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import Button from '../Button';

describe('Button Component', () => {
  test('renders button with text', () => {
    render(<Button>Click me</Button>);
    const button = screen.getByText('Click me');
    expect(button).toBeInTheDocument();
  });

  test('calls onClick handler when clicked', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    const button = screen.getByText('Click me');
    fireEvent.click(button);
    
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  test('disables button when disabled prop is true', () => {
    render(<Button disabled>Click me</Button>);
    const button = screen.getByText('Click me');
    expect(button).toBeDisabled();
  });
});
```

### Integration Testing with Cypress

```javascript
// cypress/e2e/auth.cy.js
describe('Authentication Flow', () => {
  beforeEach(() => {
    cy.visit('http://localhost:3000/login');
  });

  it('should login successfully', () => {
    cy.get('input[name="email"]').type('user@example.com');
    cy.get('input[name="password"]').type('password123');
    cy.get('button[type="submit"]').click();
    
    cy.url().should('include', '/dashboard');
    cy.get('.user-welcome').should('be.visible');
  });

  it('should show error on invalid credentials', () => {
    cy.get('input[name="email"]').type('invalid@example.com');
    cy.get('input[name="password"]').type('wrongpassword');
    cy.get('button[type="submit"]').click();
    
    cy.get('.error-message').should('be.visible');
    cy.url().should('include', '/login');
  });
});
```

## Accessibility

### ARIA Labels and Semantic HTML

```jsx
// components/AccessibleForm.jsx
const AccessibleForm = () => {
  return (
    <form aria-labelledby="form-title">
      <h2 id="form-title">User Registration</h2>
      
      <label htmlFor="email">Email Address</label>
      <input
        id="email"
        type="email"
        aria-label="Email Address"
        aria-required="true"
        required
      />
      
      <label htmlFor="password">Password</label>
      <input
        id="password"
        type="password"
        aria-label="Password"
        aria-describedby="password-hint"
        required
      />
      <small id="password-hint">At least 8 characters</small>
      
      <button type="submit" aria-label="Submit registration form">
        Register
      </button>
    </form>
  );
};

export default AccessibleForm;
```

## Sources and References

### Official Documentation
- [React Documentation](https://react.dev/) - React official guide
- [Vue.js Documentation](https://vuejs.org/) - Vue.js guide
- [MDN Web Docs](https://developer.mozilla.org/) - Web standards

### State Management
- [Redux Documentation](https://redux.js.org/) - Redux guide
- [Pinia Documentation](https://pinia.vuejs.org/) - Vue state management
- [Zustand](https://github.com/pmndrs/zustand) - Lightweight state management

### Testing Libraries
- [React Testing Library](https://testing-library.com/) - Component testing
- [Jest Documentation](https://jestjs.io/) - JavaScript testing framework
- [Cypress Documentation](https://cypress.io/) - End-to-end testing

### Performance & Accessibility
- [Web Vitals](https://web.dev/vitals/) - Core Web Vitals
- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/) - Accessibility guidelines
- [Performance.now()](https://developer.mozilla.org/en-US/docs/Web/API/Performance) - Performance APIs

### Books
- "React Hooks in Action" by John Larsen
- "Vue.js 3 Design Patterns and Best Practices" by Paul Halliday
- "Web Accessibility by Example" by W. James Maclachlan

---

**Next:** [Testing Strategies Guide](./testing-strategies.md)
