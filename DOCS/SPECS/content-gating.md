# Content Gating Specification

## Implementation Order
This module should be implemented SIXTH after Payment Integration as it:
- Depends on membership and subscription systems
- Requires payment processing for access
- Enables the widget integration

## Related Specifications
- [Membership Management](./membership-management.md) - Access rules
- [Widget Integration](./widget-integration.md) - Client implementation
- [Payment Integration](./payment-integration.md) - Access verification

## Overview
The Content Gating system provides tools for protecting and managing access to content based on membership levels. It includes an embeddable JavaScript widget for dynamic content protection on static HTML sites.

## Features

### 1. Content Management
- Create and manage gated content
- Support multiple content types (HTML, text, URL)
- Version control for content updates
- Content organization and categorization
- Publishing workflow

### 2. Access Control
- Map content to membership plans
- Define access rules and permissions
- Handle content visibility
- Manage content restrictions
- Support for preview/excerpt content

### 3. Widget Integration
- Lightweight embeddable JavaScript
- Dynamic content loading
- Access verification
- Graceful fallback handling
- Customizable messaging

### 4. Data Model

```typescript
interface ContentItem {
  id: string;
  tenant_id: string;
  title: string;
  description: string | null;
  content_type: 'html' | 'text' | 'url';
  content: string;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

interface ContentAccess {
  id: string;
  content_id: string;
  plan_id: string;
  created_at: string;
}
```

### 5. Widget Implementation

```javascript
// Embeddable widget code
class MembershipWidget {
  constructor(config) {
    this.apiKey = config.apiKey;
    this.contentId = config.contentId;
  }

  async init() {
    const hasAccess = await this.checkAccess();
    if (!hasAccess) {
      this.showUpgradeBanner();
    } else {
      this.showContent();
    }
  }

  async checkAccess() {
    // Implementation of access check
  }

  showUpgradeBanner() {
    // Implementation of upgrade prompt
  }

  showContent() {
    // Implementation of content display
  }
}
```

### 6. API Endpoints

#### Content Management
- GET /api/content - List content items
- POST /api/content - Create content
- GET /api/content/:id - Get content details
- PUT /api/content/:id - Update content
- DELETE /api/content/:id - Delete content

#### Access Control
- GET /api/content/:id/access - Check access
- POST /api/content/:id/access - Grant access
- DELETE /api/content/:id/access - Revoke access

### 7. Security Considerations
- Content encryption
- Access token validation
- Rate limiting
- XSS prevention
- CORS configuration