import React from 'react';
import { ContentItem } from '../../types';
import { Button } from '../ui/button';
import { formatDate } from '../../lib/utils';
import { FileText, Link as LinkIcon, Code } from 'lucide-react';

interface ContentCardProps {
  content: ContentItem;
  onEdit: (content: ContentItem) => void;
  onDelete: (content: ContentItem) => void;
  onTogglePublish: (content: ContentItem) => void;
}

export function ContentCard({
  content,
  onEdit,
  onDelete,
  onTogglePublish,
}: ContentCardProps) {
  const getContentTypeIcon = () => {
    switch (content.content_type) {
      case 'html':
        return <Code className="h-5 w-5" />;
      case 'url':
        return <LinkIcon className="h-5 w-5" />;
      default:
        return <FileText className="h-5 w-5" />;
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-start gap-3">
          <div className="p-2 bg-gray-100 rounded-lg">
            {getContentTypeIcon()}
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{content.title}</h3>
            <p className="text-sm text-gray-500">{content.description}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => onEdit(content)}
          >
            Edit
          </Button>
          <Button
            variant="danger"
            size="sm"
            onClick={() => onDelete(content)}
          >
            Delete
          </Button>
        </div>
      </div>
      
      <div className="flex items-center justify-between text-sm text-gray-500">
        <span>Created: {formatDate(new Date(content.created_at))}</span>
        <Button
          variant={content.is_published ? 'secondary' : 'primary'}
          size="sm"
          onClick={() => onTogglePublish(content)}
        >
          {content.is_published ? 'Unpublish' : 'Publish'}
        </Button>
      </div>
    </div>
  );
}