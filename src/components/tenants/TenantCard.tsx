import React, { useEffect, useState } from 'react';
import { Tenant } from '../../types';
import { Button } from '../ui/button';
import { Building2, Users, CreditCard, Trash2, AlertCircle, Loader2 } from 'lucide-react';
import { formatDate, formatCurrency } from '../../lib/utils';
import { getTenantStats, deleteTenant } from '../../lib/tenants';

interface TenantCardProps {
  tenant: Tenant;
  onEdit: () => void;
  onRefresh: () => void;
}

export function TenantCard({ tenant, onEdit, onRefresh }: TenantCardProps) {
  const [stats, setStats] = useState<{
    total_users: number;
    active_plans: number;
    total_revenue: number;
  } | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    fetchStats();
  }, [tenant.id]);

  async function fetchStats() {
    try {
      const data = await getTenantStats(tenant.id);
      setStats(data);
    } catch (error) {
      console.error('Error fetching tenant stats:', error);
    }
  }

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await deleteTenant(tenant.id);
      onRefresh();
    } catch (error) {
      console.error('Error deleting tenant:', error);
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-700';
      case 'inactive':
        return 'bg-red-100 text-red-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const getSubscriptionColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-700';
      case 'canceled':
        return 'bg-red-100 text-red-700';
      case 'past_due':
        return 'bg-yellow-100 text-yellow-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-start gap-3">
          <div className="p-2 bg-gray-100 rounded-lg">
            <Building2 className="h-5 w-5 text-gray-600" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{tenant.name}</h3>
            <p className="text-sm text-gray-500">ID: {tenant.id.slice(0, 8)}</p>
          </div>
        </div>
        <div>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setShowDeleteConfirm(true)}
            className="mr-2"
          >
            <Trash2 className="h-4 w-4" />
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={onEdit}
          >
            Edit
          </Button>
        </div>
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-500">Status</span>
          <span className={`px-2.5 py-0.5 rounded-full font-medium ${getStatusColor(tenant.status)}`}>
            {tenant.status}
          </span>
        </div>

        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-500">Subscription</span>
          <span className={`px-2.5 py-0.5 rounded-full font-medium ${getSubscriptionColor(tenant.subscription_status)}`}>
            {tenant.subscription_status}
          </span>
        </div>

        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-500">Created</span>
          <span className="text-gray-900">{formatDate(new Date(tenant.created_at))}</span>
        </div>
      </div>

      <div className="mt-6 pt-4 border-t border-gray-200">
        <div className="grid grid-cols-2 gap-4">
          <div className="flex items-center gap-2">
            <Users className="h-4 w-4 text-gray-400" />
            <span className="text-sm text-gray-600">
              {stats ? `${stats.total_users} Users` : '...'}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <CreditCard className="h-4 w-4 text-gray-400" />
            <span className="text-sm text-gray-600">
              {stats ? `${stats.active_plans} Plans` : '...'}
            </span>
          </div>
        </div>
        {stats && (
          <div className="mt-4 pt-4 border-t border-gray-200">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-500">Total Revenue</span>
              <span className="text-sm font-medium text-gray-900">
                {formatCurrency(stats.total_revenue)}
              </span>
            </div>
          </div>
        )}
      </div>

      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl p-6 max-w-md w-full mx-4">
            <div className="flex items-center gap-3 mb-4">
              <AlertCircle className="h-6 w-6 text-red-600" />
              <h3 className="text-lg font-semibold text-gray-900">
                Delete Tenant
              </h3>
            </div>
            <p className="text-gray-600 mb-6">
              Are you sure you want to delete {tenant.name}? This action cannot be
              undone and will affect all users and data associated with this tenant.
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
                  'Delete Tenant'
                )}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}