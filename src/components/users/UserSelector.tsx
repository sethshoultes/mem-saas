import React, { useState, useEffect } from 'react';
import { User } from '../../types';
import { supabase } from '../../lib/supabase';
import { Search, User as UserIcon } from 'lucide-react';

interface UserSelectorProps {
  tenantId: string;
  value: string;
  onChange: (userId: string) => void;
  className?: string;
}

export function UserSelector({
  tenantId,
  value,
  onChange,
  className = ''
}: UserSelectorProps) {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    if (tenantId) {
      fetchUsers();
    }
  }, [tenantId]);

  async function fetchUsers() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: profiles, error } = await supabase
        .rpc('get_accessible_users', { viewer_id: user.id })
        .eq('tenant_id', tenantId);

      if (error) throw error;

      // Get emails for each user
      const emailPromises = profiles.map(async profile => {
        const { data: email } = await supabase
          .rpc('get_user_email', { user_id: profile.id });
        return { id: profile.id, email };
      });

      const emails = await Promise.all(emailPromises);
      const combinedUsers: User[] = profiles.map(profile => ({
        id: profile.id,
        email: emails.find(e => e.id === profile.id)?.email || '',
        profile,
      }));

      setUsers(combinedUsers);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setIsLoading(false);
    }
  }

  const filteredUsers = users.filter(user =>
    user.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (user.profile?.full_name || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const selectedUser = users.find(u => u.id === value);

  return (
    <div className={`relative ${className}`}>
      <div
        className="flex items-center gap-2 w-full px-3 py-2 border border-gray-300 rounded-md cursor-pointer hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
        onClick={() => setIsOpen(!isOpen)}
      >
        <UserIcon className="h-4 w-4 text-gray-400" />
        <span className="flex-1 text-gray-700">
          {isLoading ? 'Loading users...' :
           selectedUser ? (
             <div>
               <div className="font-medium">{selectedUser.profile?.full_name}</div>
               <div className="text-xs text-gray-500">{selectedUser.email}</div>
             </div>
           ) : 'Select a user'}
        </span>
      </div>

      {isOpen && (
        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg">
          <div className="p-2 border-b border-gray-200">
            <div className="relative">
              <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                className="w-full pl-8 pr-3 py-1 border border-gray-200 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Search users..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          </div>
          
          <div className="max-h-60 overflow-y-auto">
            {filteredUsers.map(user => (
              <div
                key={user.id}
                className={`px-3 py-2 cursor-pointer hover:bg-gray-100 ${
                  user.id === value ? 'bg-blue-50 text-blue-600' : 'text-gray-700'
                }`}
                onClick={() => {
                  onChange(user.id);
                  setIsOpen(false);
                }}
              >
                <div className="font-medium">{user.profile?.full_name}</div>
                <div className="text-xs text-gray-500">{user.email}</div>
              </div>
            ))}
            {filteredUsers.length === 0 && (
              <div className="px-3 py-2 text-sm text-gray-500">
                No users found
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}