import React, { useState } from 'react';
import { Button } from '../ui/button';
import { AlertCircle, Lock, Eye, Code, User } from 'lucide-react';
import { verifyAccess, getContentPreview } from '../../lib/access-control';
import { supabase } from '../../lib/supabase';

const DEMO_USERS = [
  {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Demo Free User',
    description: 'No active subscriptions'
  },
  {
    id: '22222222-2222-2222-2222-222222222222',
    name: 'Demo Premium User',
    description: 'Has active premium subscription'
  }
];

interface WidgetDemoProps {
  contentId: string;
}

export function WidgetDemo({ contentId }: WidgetDemoProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [content, setContent] = useState<{
    hasAccess: boolean;
    accessType: 'full' | 'preview' | null;
    content: string | null;
  } | null>(null);
  const [showCode, setShowCode] = useState(false);
  const [selectedUser, setSelectedUser] = useState<string | null>(null);

  const testAccess = async (userId: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const { data: contentData } = await supabase
        .from('content_items')
        .select('content, preview_content')
        .eq('id', contentId)
        .single();

      const access = await verifyAccess(contentId, userId);
      
      setContent({
        hasAccess: access.hasAccess,
        accessType: access.accessType,
        content: access.accessType === 'full' ? contentData?.content :
                access.accessType === 'preview' ? contentData?.preview_content :
                null
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to verify access');
    } finally {
      setIsLoading(false);
    }
  };

  const embedCode = `
<div class="membership-content" data-content-id="${contentId}">
  <script>
    window.MembershipWidget.init({
      apiKey: 'your-api-key',
      contentId: '${contentId}'
    });
  </script>
</div>`;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">Widget Demo</h3>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => setShowCode(!showCode)}
        >
          <Code className="h-4 w-4 mr-2" />
          {showCode ? 'Hide Code' : 'Show Code'}
        </Button>
      </div>

      {showCode && (
        <div className="bg-gray-900 rounded-lg p-4 relative group">
          <Button
            variant="secondary"
            size="sm"
            className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity"
            onClick={() => {
              navigator.clipboard.writeText(embedCode);
            }}
          >
            Copy
          </Button>
          <pre className="text-gray-300 text-sm overflow-x-auto">
            {embedCode}
          </pre>
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg divide-y divide-gray-200">
        <div className="p-4">
          <h4 className="font-medium text-gray-900 mb-4">Test Access Levels</h4>
          <div className="space-y-4">
            <div className="grid grid-cols-1 gap-2">
              {DEMO_USERS.map(user => (
                <div
                  key={user.id}
                  className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                    user.id === selectedUser
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 hover:border-blue-300'
                  }`}
                  onClick={() => {
                    setSelectedUser(user.id);
                    testAccess(user.id);
                  }}
                >
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-gray-100 rounded-full">
                      <User className="h-4 w-4 text-gray-600" />
                    </div>
                    <div>
                      <div className="font-medium text-gray-900">{user.name}</div>
                      <div className="text-sm text-gray-500">{user.description}</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="p-4">
          <h4 className="font-medium text-gray-900 mb-4">Content Preview</h4>
          
          {isLoading ? (
            <div className="text-center py-4 text-gray-500">
              Checking access...
            </div>
          ) : error ? (
            <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
              <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
              <p className="text-sm text-red-600">{error}</p>
            </div>
          ) : content ? (
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                {content.hasAccess ? (
                  <Eye className="h-5 w-5 text-green-500" />
                ) : (
                  <Lock className="h-5 w-5 text-red-500" />
                )}
                <span className={`text-sm font-medium ${
                  content.hasAccess ? 'text-green-700' : 'text-red-700'
                }`}>
                  {content.hasAccess
                    ? `${content.accessType === 'full' ? 'Full' : 'Preview'} Access`
                    : 'No Access'}
                </span>
              </div>

              {content.content ? (
                <div className="prose max-w-none">
                  <p>{content.content}</p>
                </div>
              ) : (
                <div className="bg-gray-50 rounded-lg p-4 text-center">
                  <Lock className="h-8 w-8 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-600">
                    This content is not available with your current access level.
                  </p>
                  <Button
                    variant="primary"
                    size="sm"
                    className="mt-4"
                  >
                    Upgrade to Access
                  </Button>
                </div>
              )}
            </div>
          ) : (
            <div className="text-center py-4 text-gray-500">
              Select an access level to test
            </div>
          )}
        </div>
      </div>
    </div>
  );
}