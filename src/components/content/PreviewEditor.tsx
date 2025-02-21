import React, { useState } from 'react';
import { Button } from '../ui/button';
import { Eye, Save } from 'lucide-react';

interface PreviewEditorProps {
  contentId: string;
  initialContent?: string;
  onSave: (content: string) => Promise<void>;
}

export function PreviewEditor({
  contentId,
  initialContent = '',
  onSave
}: PreviewEditorProps) {
  const [content, setContent] = useState(initialContent);
  const [isLoading, setIsLoading] = useState(false);

  const handleSave = async () => {
    setIsLoading(true);
    try {
      await onSave(content);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Preview Content</h3>
          <p className="text-sm text-gray-500">
            Create a preview version of your content for limited access
          </p>
        </div>
        <Button
          variant="secondary"
          size="sm"
          onClick={handleSave}
          disabled={isLoading}
        >
          <Save className="h-4 w-4 mr-2" />
          Save Preview
        </Button>
      </div>

      <div className="relative">
        <div className="absolute top-2 right-2">
          <Eye className="h-4 w-4 text-gray-400" />
        </div>
        <textarea
          className="w-full h-48 p-4 border border-gray-200 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Enter preview content here..."
        />
      </div>

      <div className="text-sm text-gray-500">
        This preview will be shown to users with preview-only access.
      </div>
    </div>
  );
}