import React from 'react';
import { Button } from '../ui/button';
import { Download, Trash, UserX, UserCheck } from 'lucide-react';
import { User } from '../../types';
import { updateUserProfile } from '../../lib/auth';

interface BulkActionsProps {
  selectedUsers: User[];
  onClearSelection: () => void;
  onRefresh: () => void;
}

export function BulkActions({ selectedUsers, onClearSelection, onRefresh }: BulkActionsProps) {
  const handleBulkStatusUpdate = async (status: 'active' | 'suspended') => {
    try {
      await Promise.all(
        selectedUsers.map(user => 
          updateUserProfile(user.id, { status })
        )
      );
      onRefresh();
      onClearSelection();
    } catch (error) {
      console.error('Error updating user statuses:', error);
    }
  };

  const handleExportUsers = () => {
    const csvContent = [
      ['ID', 'Email', 'Full Name', 'Role', 'Status', 'Created At'].join(','),
      ...selectedUsers.map(user => [
        user.id,
        user.email,
        user.profile?.full_name || '',
        user.profile?.role || '',
        user.profile?.status || '',
        user.profile?.created_at || ''
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `users-export-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  };

  return (
    <div className="bg-white shadow rounded-lg p-4 flex items-center justify-between">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium text-gray-700">
          {selectedUsers.length} users selected
        </span>
        <Button
          variant="secondary"
          size="sm"
          onClick={onClearSelection}
        >
          Clear Selection
        </Button>
      </div>
      
      <div className="flex items-center gap-2">
        <Button
          variant="secondary"
          size="sm"
          onClick={handleExportUsers}
        >
          <Download className="h-4 w-4 mr-2" />
          Export Selected
        </Button>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => handleBulkStatusUpdate('suspended')}
        >
          <UserX className="h-4 w-4 mr-2" />
          Suspend Selected
        </Button>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => handleBulkStatusUpdate('active')}
        >
          <UserCheck className="h-4 w-4 mr-2" />
          Activate Selected
        </Button>
      </div>
    </div>
  );
}