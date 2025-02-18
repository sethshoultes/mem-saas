import React from 'react';
import { User, UserActivity } from '../../types';
import { Button } from '../ui/button';
import { ChevronDown, ChevronUp, MoreVertical, Shield, ShieldAlert, ShieldCheck } from 'lucide-react';
import { updateUserProfile } from '../../lib/auth';
import { UserActivityLog } from './UserActivity';
import { UserProfile } from './UserProfile';

interface UserListItemProps {
  user: User;
  isSelected: boolean;
  onSelect: (isSelected: boolean) => void;
  onRefresh: () => void;
  onEdit: () => void;
  activities?: UserActivity[];
}

export function UserListItem({
  user,
  isSelected,
  onSelect,
  onRefresh,
  onEdit,
  activities = []
}: UserListItemProps) {
  const [showActivity, setShowActivity] = React.useState(false);
  const [showProfile, setShowProfile] = React.useState(false);

  const getRoleIcon = () => {
    switch (user.profile?.role) {
      case 'admin':
        return <ShieldAlert className="h-4 w-4 text-red-500" />;
      case 'tenant_admin':
        return <ShieldCheck className="h-4 w-4 text-blue-500" />;
      default:
        return <Shield className="h-4 w-4 text-gray-400" />;
    }
  };

  const getStatusColor = () => {
    switch (user.profile?.status) {
      case 'active':
        return 'bg-green-100 text-green-700';
      case 'suspended':
        return 'bg-red-100 text-red-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const handleStatusToggle = async () => {
    if (!user.profile) return;

    const newStatus = user.profile.status === 'active' ? 'suspended' : 'active';
    
    try {
      await updateUserProfile(user.id, { status: newStatus });
      onRefresh();
    } catch (error) {
      console.error('Error updating user status:', error);
    }
  };

  return (
    <div className="grid grid-cols-4 gap-4 p-4 items-center hover:bg-gray-50">
      <div className="flex items-center gap-3">
        <input
          type="checkbox"
          className="h-4 w-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
          checked={isSelected}
          onChange={(e) => onSelect(e.target.checked)}
        />
        <div 
          className="h-8 w-8 rounded-full bg-gray-100 flex items-center justify-center cursor-pointer hover:bg-gray-200"
          onClick={() => setShowProfile(true)}
        >
          <span className="text-sm font-medium text-gray-600">
            {user.profile?.full_name.charAt(0) || user.email.charAt(0)}
          </span>
        </div>
        <div 
          className="cursor-pointer hover:text-blue-600"
          onClick={() => setShowProfile(true)}
        >
          <div className="font-medium text-gray-900">
            {user.profile?.full_name || 'Unnamed User'}
          </div>
          <div className="text-sm text-gray-500">
            ID: {user.id.slice(0, 8)}
          </div>
        </div>
      </div>
      
      <div className="text-gray-500">{user.email}</div>
      
      <div className="flex items-center gap-2">
        {getRoleIcon()}
        <span className="text-sm text-gray-700">
          {user.profile?.role || 'user'}
        </span>
      </div>
      
      <div className="flex items-center justify-between">
        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor()}`}>
          {user.profile?.status || 'inactive'}
        </span>
        
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setShowActivity(!showActivity)}
            className="p-1"
          >
            {showActivity ? (
              <ChevronUp className="h-4 w-4" />
            ) : (
              <ChevronDown className="h-4 w-4" />
            )}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={handleStatusToggle}
          >
            {user.profile?.status === 'active' ? 'Suspend' : 'Activate'}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={onEdit}
            className="p-1"
          >
            <MoreVertical className="h-4 w-4" />
          </Button>
        </div>
      </div>
      
      {showActivity && activities.length > 0 && (
        <div className="col-span-4 mt-4">
          <UserActivityLog activities={activities} />
        </div>
      )}
      
      {showProfile && (
        <UserProfile
          user={user}
          activities={activities}
          onClose={() => setShowProfile(false)}
          onEdit={onEdit}
          onRefresh={onRefresh}
        />
      )}
    </div>
  );
}