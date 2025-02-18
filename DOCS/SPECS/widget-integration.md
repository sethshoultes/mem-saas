# Widget Integration Specification

## Implementation Order
This module should be implemented LAST after Content Gating as it:
- Depends on all other systems being operational
- Provides client-side implementation
- Requires complete backend services

## Related Specifications
- [Content Gating](./content-gating.md) - Access control
- [Membership Management](./membership-management.md) - Subscription verification
- [User Management](./user-management.md) - Authentication

## Overview
The Widget Integration system provides a lightweight, embeddable JavaScript widget that enables content gating on static HTML websites. The widget handles authentication, access verification, and dynamic content rendering.

## Features

### 1. Core Functionality
- Content access verification
- Dynamic content loading
- Authentication handling
- Error management
- Performance optimization

### 2. Integration Methods
- Script tag embedding
- NPM package
- Content attributes
- Configuration options
- Event handling

### 3. Widget Configuration

```typescript
interface WidgetConfig {
  apiKey: string;
  tenant: string;
  theme?: {
    primary: string;
    secondary: string;
    font: string;
  };
  messages?: {
    unauthorized: string;
    loading: string;
    error: string;
  };
  callbacks?: {
    onLoad?: () => void;
    onError?: (error: Error) => void;
    onAccess?: (granted: boolean) => void;
  };
}
```

### 4. Implementation Example

```html
<!-- Basic Integration -->
<div class="membership-content" data-content-id="123">
  <p>Premium content here...</p>
</div>

<script>
  window.MembershipWidget.init({
    apiKey: 'your-api-key',
    tenant: 'your-tenant-id'
  });
</script>

<!-- Advanced Integration -->
<script>
  const widget = new MembershipWidget({
    apiKey: 'your-api-key',
    tenant: 'your-tenant-id',
    theme: {
      primary: '#007bff',
      secondary: '#6c757d',
      font: 'Arial, sans-serif'
    },
    messages: {
      unauthorized: 'Please subscribe to access this content',
      loading: 'Loading content...',
      error: 'Error loading content'
    },
    callbacks: {
      onAccess: (granted) => {
        console.log('Access granted:', granted);
      }
    }
  });

  widget.init();
</script>
```

### 5. API Methods

```typescript
interface MembershipWidget {
  init(): Promise<void>;
  checkAccess(contentId: string): Promise<boolean>;
  showContent(contentId: string): Promise<void>;
  hideContent(contentId: string): void;
  refreshToken(): Promise<void>;
  destroy(): void;
}
```

### 6. Events

```typescript
interface WidgetEvents {
  'widget:loaded': void;
  'widget:error': Error;
  'content:loading': string;
  'content:loaded': string;
  'access:granted': string;
  'access:denied': string;
  'auth:required': void;
  'auth:success': void;
  'auth:error': Error;
}
```

### 7. Security Considerations
- Secure token handling
- XSS prevention
- CORS configuration
- Rate limiting
- Error handling
- Data validation

### 8. Performance Optimization
- Minimal bundle size
- Lazy loading
- Caching strategies
- Resource optimization
- Error recovery