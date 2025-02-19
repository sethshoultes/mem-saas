import React, { useState, useEffect } from 'react';
import { Tenant } from '../../types';
import { Button } from '../ui/button';
import { X } from 'lucide-react';
import { createTenant, updateTenant } from '../../lib/tenants';

interface TenantModalProps {
  tenant?: Tenant;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function TenantModal({
  tenant,
  isOpen,
  onClose,
  onSuccess,
}: TenantModalProps) {
  const [formData, setFormData] = useState(() => ({
    name: '',
    status: 'active' as const,
  }));

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (tenant) {
      setFormData({
        name: tenant.name,
        status: tenant.status,
      });
    } else {
      setFormData({
        name: '',
        status: 'active',
      });
    }
  }, [tenant]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      if (tenant) {
        await updateTenant(tenant.id, formData);
      } else {
        await createTenant(formData.name);
      }
      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">
            {tenant ? 'Edit Tenant' : 'Add New Tenant'}
          </h2>
          <Button
            variant="secondary"
            size="sm"
            className="p-1"
            onClick={onClose}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>

        <form onSubmit={handleSubmit} className="p-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">
              Tenant Name
            </label>
            <input
              type="text"
              className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              required
            />
          </div>

          {tenant && (
            <div>
              <label className="block text-sm font-medium text-gray-700">
                Status
              </label>
              <select
                className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
                value={formData.status}
                onChange={(e) => setFormData({
                  ...formData,
                  status: e.target.value as 'active' | 'inactive'
                })}
                required
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>
          )}

          {error && (
            <div className="text-sm text-red-600 bg-red-50 p-3 rounded-md">
              {error}
            </div>
          )}

          <div className="flex justify-end gap-3 pt-4">
            <Button
              type="button"
              variant="secondary"
              onClick={onClose}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isLoading}
            >
              {isLoading ? 'Saving...' : tenant ? 'Update Tenant' : 'Create Tenant'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}