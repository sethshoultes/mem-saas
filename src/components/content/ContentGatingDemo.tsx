import React, { useState } from 'react';
import { ContentGating } from './ContentGating';
import { Button } from '../ui/button';
import { Plus, FileText, Eye, Lock } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAdminStore } from '../../store';

interface DemoContent {
  id: string;
  title: string;
  content: string;
  is_published: boolean;
}

export function ContentGatingDemo() {
  const [contents, setContents] = useState<DemoContent[]>([]);
  const [selectedContent, setSelectedContent] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const { currentUser } = useAdminStore();

  React.useEffect(() => {
    if (currentUser?.profile?.tenant_id) {
      fetchContents();
    }
  }, [currentUser]);

  async function fetchContents() {
    try {
      const { data, error } = await supabase
        .from('content_items')
        .select('id, title, content, is_published')
        .eq('tenant_id', currentUser!.profile!.tenant_id);

      if (error) throw error;
      setContents(data || []);
    } catch (error) {
      console.error('Error fetching contents:', error);
    } finally {
      setIsLoading(false);
    }
  }

  async function createDemoContent() {
    if (!currentUser?.profile?.tenant_id) {
      alert('Please set up a tenant account before creating content.');
      return;
    }

    try {
      // First verify the tenant exists
      const { data: tenant, error: tenantError } = await supabase
        .from('tenants')
        .select('id')
        .eq('id', currentUser.profile.tenant_id)
        .single();

      if (tenantError || !tenant) {
        throw new Error('Invalid tenant ID or tenant does not exist');
      }

      const { data, error } = await supabase
        .from('content_items')
        .insert({
          tenant_id: tenant.id,
          title: `Demo Content ${contents.length + 1}`,
          content: 'This is the full content that will be protected by access rules.',
          content_type: 'text',
          is_published: true
        })
        .select()
        .single();

      if (error) throw error;
      fetchContents();
      setSelectedContent(data.id);
    } catch (error) {
      console.error('Error creating content:', error);
      alert('Failed to create content. Please ensure your tenant account is properly set up.');
    }
  }

  if (!currentUser?.profile?.tenant_id) {
    return (
      <div className="p-8 text-center">
        <div className="bg-yellow-50 p-4 rounded-lg inline-block">
          <p className="text-yellow-800">
            Please set up a tenant account before creating content.
          </p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return <div className="flex justify-center p-8">Loading content...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Content Gating Demo</h1>
          <p className="text-sm text-gray-500 mt-1">
            Test content access with different user types and membership levels
          </p>
        </div>
        <Button onClick={createDemoContent}>
          <Plus className="h-4 w-4 mr-2" />
          Create Demo Content
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-1 space-y-4">
          <div className="bg-white rounded-lg shadow-sm p-4">
            <div className="mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Content List</h2>
              <p className="text-sm text-gray-500 mt-1">
                Select content to manage access rules and preview settings
              </p>
            </div>
            {contents.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                No content available. Create some demo content to get started.
              </div>
            ) : (
              <div className="space-y-2">
                {contents.map(content => (
                  <div
                    key={content.id}
                    className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                      content.id === selectedContent
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-blue-300'
                    }`}
                    onClick={() => setSelectedContent(content.id)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <FileText className="h-4 w-4 text-gray-400" />
                        <span className="font-medium text-gray-900">
                          {content.title}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        {content.is_published ? (
                          <Eye className="h-4 w-4 text-green-500" />
                        ) : (
                          <Lock className="h-4 w-4 text-gray-400" />
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="lg:col-span-2">
          {selectedContent ? (
            <div className="bg-white rounded-lg shadow-sm p-6">
              <ContentGating contentId={selectedContent} />
            </div>
          ) : (
            <div className="bg-white rounded-lg shadow-sm p-8 text-center">
              <Lock className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                Select Content to Manage Access
              </h3>
              <p className="text-gray-500">
                Choose a content item from the list to configure access rules and preview content.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}