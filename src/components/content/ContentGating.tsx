import React, { useState, useEffect } from 'react';
import { AccessRuleEditor } from './AccessRuleEditor';
import { PreviewEditor } from './PreviewEditor';
import { WidgetDemo } from './WidgetDemo';
import { supabase } from '../../lib/supabase';
import { AlertCircle } from 'lucide-react';

interface ContentGatingProps {
  contentId: string;
}

export function ContentGating({ contentId }: ContentGatingProps) {
  const [previewContent, setPreviewContent] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!contentId) return;
    setIsLoading(true);
    fetchPreviewContent();
  }, [contentId]);

  const fetchPreviewContent = async () => {
    try {
      setError(null);
      const { data, error } = await supabase
        .from('content_items')
        .select('preview_content')
        .eq('id', contentId)
        .single();

      if (error) throw error;
      setPreviewContent(data?.preview_content || '');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load preview content');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSavePreview = async (content: string) => {
    try {
      const { error } = await supabase
        .from('content_items')
        .update({ preview_content: content })
        .eq('id', contentId);

      if (error) throw error;
      setPreviewContent(content);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save preview content');
    }
  };

  return (
    <div className="space-y-8">
      {error && (
        <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}

      {isLoading ? (
        <div className="text-center py-4 text-gray-500">Loading content...</div>
      ) : (
        <>
      <AccessRuleEditor
        contentId={contentId}
        onUpdate={fetchPreviewContent}
      />

      <PreviewEditor
        contentId={contentId}
        initialContent={previewContent}
        onSave={handleSavePreview}
      />

      <WidgetDemo contentId={contentId} />
        </>
      )}
    </div>
  );
}