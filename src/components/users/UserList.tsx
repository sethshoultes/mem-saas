import React, { useEffect, useState } from 'react';
import { User, UserActivity } from '../../types';
import { supabase } from '../../lib/supabase';
import { UserListItem } from './UserListItem';
import { BulkActions } from './BulkActions';
import { Button } from '../ui/button';
import { Plus, Search } from 'lucide-react';
import { UserModal } from './UserModal';

export function UserList() {
  const [users, setUsers] = useState<User[]>([]);
  const [activities, setActivities] = useState<Record<string, UserActivity[]>>({});
  const [selectedUsers, setSelectedUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | undefined>();

  useEffect(() => {
    fetchUsers();
  }, []);

  async function fetchUsers() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data: profiles, error } = await supabase
        .rpc('get_accessible_users', { viewer_id: user.id });
      
      if (error) throw error;
      if (!profiles) throw new Error('No profiles returned');

      // Fetch activities for all users
      const { data: allActivities, error: activitiesError } = await supabase
        .from('user_activity')
        .select('*')
        .in('user_id', profiles.map(p => p.id))
        .order('created_at', { ascending: false });

      if (activitiesError) throw activitiesError;

      // Group activities by user
      const groupedActivities = allActivities.reduce((acc, activity) => {
        acc[activity.user_id] = acc[activity.user_id] || [];
        acc[activity.user_id].push(activity);
        return acc;
      }, {} as Record<string, UserActivity[]>);

      setActivities(groupedActivities);
      const combinedUsers: User[] = profiles.map(profile => ({
        id: profile.id,
        email: profile.id === user.id ? user.email : profile.email || '',
        profile,
      }));

      setUsers(combinedUsers);
    } catch (error) {
      console.error('Error fetching users:', error instanceof Error ? error.message : error);
    } finally {
      setIsLoading(false);
    }
  }

  const filteredUsers = users.filter(user => 
    user.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    user.profile?.full_name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (isLoading) {
    return <div className="flex justify-center p-8">Loading users...</div>;
  }

  const handleUserSelect = (user: User, isSelected: boolean) => {
    if (isSelected) {
      setSelectedUsers([...selectedUsers, user]);
    } else {
      setSelectedUsers(selectedUsers.filter(u => u.id !== user.id));
    }
  };

  const handleSelectAll = (isSelected: boolean) => {
    setSelectedUsers(isSelected ? filteredUsers : []);
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Users</h1>
        <Button onClick={() => {
          setSelectedUser(undefined);
          setIsModalOpen(true);
        }}>
          <Plus className="h-4 w-4 mr-2" />
          Add User
        </Button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          placeholder="Search users..."
          className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      {selectedUsers.length > 0 && (
        <BulkActions
          selectedUsers={selectedUsers}
          onClearSelection={() => setSelectedUsers([])}
          onRefresh={fetchUsers}
        />
      )}

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="grid grid-cols-4 gap-4 p-4 bg-gray-50 border-b border-gray-200 font-medium text-sm text-gray-500">
          <div className="flex items-center">
            <input
              type="checkbox"
              className="h-4 w-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
              checked={selectedUsers.length === filteredUsers.length}
              onChange={(e) => handleSelectAll(e.target.checked)}
            />
            <span className="ml-3">Name</span>
          </div>
          <div>Email</div>
          <div>Role</div>
          <div>Status</div>
        </div>
        <div className="divide-y divide-gray-200">
          {filteredUsers.map(user => (
            <UserListItem
              key={user.id}
              user={user}
              isSelected={selectedUsers.some(u => u.id === user.id)}
              onSelect={(isSelected) => handleUserSelect(user, isSelected)}
              onRefresh={fetchUsers}
              activities={activities[user.id]}
              onEdit={() => {
                setSelectedUser(user);
                setIsModalOpen(true);
              }}
            />
          ))}
        </div>
      </div>
      
      <UserModal
        user={selectedUser}
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false);
          setSelectedUser(undefined);
        }}
        onSuccess={fetchUsers}
      />
    </div>
  );
}