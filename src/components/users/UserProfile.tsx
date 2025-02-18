import React from 'react';
import { User, UserActivity } from '../../types';
import { Button } from '../ui/button';
import { X, Mail, Building2, Shield, Calendar, Loader2, Trash2 } from 'lucide-react';
import { formatDate } from '../../lib/utils';
import { UserActivityLog } from './UserActivity';
import { resetPassword, deleteUser } from '../../lib/auth';

interface UserProfileProps {
  user: User;
  activities: UserActivity[];
  onClose: () => void;
  onEdit: () => void;
  onRefresh: () => void;
}

export function UserProfile({ user, activities, onClose, onEdit, onRefresh }: UserProfileProps) {
  const [isResetting, setIsResetting] = React.useState(false);
  const [resetStatus, setResetStatus] = React.useState<'idle' | 'success' | 'error'>('idle');
  const [isDeleting, setIsDeleting] = React.useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = React.useState(false);

  const handleResetPassword = async () => {
    setIsResetting(true);
    setResetStatus('idle');
    
    try {
      await resetPassword(user.email);
      setResetStatus('success');
      
      // Log the activity
      await supabase.rpc('log_user_activity', {
        p_user_id: user.id,
        p_action: 'password_reset_requested',
        p_details: { requested_at: new Date().toISOString() },
      });
    } catch (error) {
      console.error('Error resetting password:', error);
      setResetStatus('error');
    } finally {
      setIsResetting(false);
    }
  };

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await deleteUser(user.id);
      onClose();
      onRefresh();
    } catch (error) {
      console.error('Error deleting user:', error);
      // Show error in UI
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">User Profile</h2>
          <Button
            variant="secondary"
            size="sm"
            className="p-1"
            onClick={onClose}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>

        <div className="p-6 space-y-6">
          {/* User Header */}
          <div className="flex items-start gap-4">
            <div className="h-16 w-16 rounded-full bg-gray-100 flex items-center justify-center">
              <span className="text-2xl font-medium text-gray-600">
                {user.profile?.full_name.charAt(0) || user.email.charAt(0)}
              </span>
            </div>
            <div className="flex-1">
              <h3 className="text-xl font-semibold text-gray-900">
                {user.profile?.full_name}
              </h3>
              <div className="mt-1 flex items-center gap-2 text-gray-500">
                <Mail className="h-4 w-4" />
                {user.email}
              </div>
              <div className="mt-4 flex items-center gap-3">
                <Button onClick={onEdit}>
                  Edit Profile
                </Button>
                <Button 
                  variant="secondary"
                  onClick={handleResetPassword}
                  disabled={isResetting}
                >
                  {isResetting ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      Sending Reset Link...
                    </>
                  ) : (
                    'Reset Password'
                  )}
                </Button>
                <Button
                  variant="danger"
                  onClick={() => setShowDeleteConfirm(true)}
                  disabled={isDeleting}
                >
                  <Trash2 className="h-4 w-4 mr-2" />
                  Delete User
                </Button>
              </div>
              {resetStatus === 'success' && (
                <p className="mt-2 text-sm text-green-600">
                  Password reset link has been sent to the user's email.
                </p>
              )}
              {resetStatus === 'error' && (
                <p className="mt-2 text-sm text-red-600">
                  Failed to send reset link. Please try again.
                </p>
              )}
            </div>
          </div>

          {/* User Details */}
          <div className="grid grid-cols-2 gap-6 pt-4 border-t border-gray-200">
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">Role</h4>
              <div className="flex items-center gap-2">
                <Shield className="h-5 w-5 text-blue-500" />
                <span className="font-medium text-gray-900">
                  {user.profile?.role || 'User'}
                </span>
              </div>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">Status</h4>
              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-sm font-medium
                ${user.profile?.status === 'active' ? 'bg-green-100 text-green-700' : 
                  user.profile?.status === 'suspended' ? 'bg-red-100 text-red-700' : 
                  'bg-gray-100 text-gray-700'}`}>
                {user.profile?.status || 'inactive'}
              </span>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">Tenant</h4>
              <div className="flex items-center gap-2">
                <Building2 className="h-5 w-5 text-gray-400" />
                <span className="text-gray-900">
                  {user.profile?.tenant_id || 'No tenant assigned'}
                </span>
              </div>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">Member Since</h4>
              <div className="flex items-center gap-2">
                <Calendar className="h-5 w-5 text-gray-400" />
                <span className="text-gray-900">
                  {formatDate(new Date(user.profile?.created_at || ''))}
                </span>
              </div>
            </div>
          </div>

          {/* Activity Log */}
          <div className="pt-6 border-t border-gray-200">
            <UserActivityLog activities={activities} />
          </div>
        </div>
      </div>
      
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl p-6 max-w-md w-full mx-4">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Delete User Account
            </h3>
            <p className="text-gray-600 mb-6">
              Are you sure you want to delete this user account? This action cannot be undone
              and will permanently remove all user data.
            </p>
            <div className="flex justify-end gap-3">
              <Button
                variant="secondary"
                onClick={() => setShowDeleteConfirm(false)}
                disabled={isDeleting}
              >
                Cancel
              </Button>
              <Button
                variant="danger"
                onClick={handleDelete}
                disabled={isDeleting}
              >
                {isDeleting ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Deleting...
                  </>
                ) : (
                  'Delete User'
                )}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}