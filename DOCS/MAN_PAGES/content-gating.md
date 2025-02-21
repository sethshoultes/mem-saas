# Content Gating System Manual

## Overview
The Content Gating system provides a flexible way to protect content based on membership levels. It supports both full and preview access modes, allowing you to create teaser content while protecting the full version.

## Components

### ContentGating
The main component that combines access rule management and preview content editing.

```tsx
import { ContentGating } from './components/content/ContentGating';

<ContentGating contentId="your-content-id" />
```

### AccessRuleEditor
Manages access rules for content, defining which membership plans can access the content and at what level.

```tsx
import { AccessRuleEditor } from './components/content/AccessRuleEditor';

<AccessRuleEditor contentId="your-content-id" onUpdate={() => {}} />
```

### PreviewEditor
Handles preview content creation and editing.

```tsx
import { PreviewEditor } from './components/content/PreviewEditor';

<PreviewEditor
  contentId="your-content-id"
  initialContent="Preview content here"
  onSave={async (content) => {}}
/>
```

## Usage Guide

### 1. Setting Up Content Protection

1. Create your content item in the database
2. Use the ContentGating component to manage access:
   ```tsx
   function ContentManager() {
     return (
       <div>
         <h1>Manage Content</h1>
         <ContentGating contentId="your-content-id" />
       </div>
     );
   }
   ```

### 2. Managing Access Rules

1. Select a membership plan from the dropdown
2. Choose access type:
   - `full`: Complete access to content
   - `preview`: Access to preview version only
3. Click "Add Access Rule"
4. Rules can be deleted using the delete button

### 3. Creating Preview Content

1. Use the preview editor to create a teaser version
2. Preview content should be engaging but limited
3. Save changes using the "Save Preview" button

### 4. Access Verification

The system automatically handles access verification through the following process:

1. Checks user's active subscriptions
2. Verifies subscription against content access rules
3. Serves appropriate content version based on access level

### 5. Integration Example

```tsx
import { ContentGating } from './components/content/ContentGating';
import { supabase } from './lib/supabase';

function ContentManager() {
  const [contentId, setContentId] = useState<string | null>(null);

  async function createContent() {
    const { data, error } = await supabase
      .from('content_items')
      .insert({
        title: 'Protected Article',
        content: 'Full article content here...',
        content_type: 'text',
        is_published: true
      })
      .select()
      .single();

    if (data) {
      setContentId(data.id);
    }
  }

  return (
    <div>
      <button onClick={createContent}>Create Content</button>
      {contentId && <ContentGating contentId={contentId} />}
    </div>
  );
}
```

## Best Practices

1. **Preview Content**
   - Keep preview content concise but valuable
   - Include hooks to encourage subscription
   - Maintain consistent quality

2. **Access Rules**
   - Start with broader access levels
   - Use preview access strategically
   - Review and update rules regularly

3. **Content Organization**
   - Group related content under similar access rules
   - Maintain clear access hierarchies
   - Document access patterns

4. **User Experience**
   - Provide clear upgrade paths
   - Explain access limitations
   - Show valuable previews

## Troubleshooting

### Common Issues

1. **Access Rules Not Applying**
   - Verify subscription status
   - Check plan IDs match
   - Confirm rule creation

2. **Preview Not Showing**
   - Verify preview content saved
   - Check access rule configuration
   - Validate content ID

3. **Permission Errors**
   - Verify user authentication
   - Check tenant ID matches
   - Confirm user has necessary roles

## API Reference

### Content Access Verification

```typescript
// Verify content access
const { data, error } = await supabase.rpc('verify_content_access', {
  content_id: 'your-content-id',
  user_id: 'current-user-id'
});

// Get content with access check
const { data, error } = await supabase.rpc('get_content_with_access', {
  content_id: 'your-content-id',
  user_id: 'current-user-id'
});
```

### Access Rule Management

```typescript
// Create access rule
const { data, error } = await supabase
  .from('content_access')
  .insert({
    content_id: 'your-content-id',
    plan_id: 'membership-plan-id',
    access_type: 'full'
  });

// Delete access rule
const { error } = await supabase
  .from('content_access')
  .delete()
  .eq('id', 'rule-id');
```

## Security Considerations

1. **Access Control**
   - Always verify access server-side
   - Never expose full content in preview
   - Validate all user inputs

2. **Data Protection**
   - Encrypt sensitive content
   - Use secure storage methods
   - Implement proper backups

3. **Audit Trail**
   - Log access changes
   - Track content modifications
   - Monitor access patterns