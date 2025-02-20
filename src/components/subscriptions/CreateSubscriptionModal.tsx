import React, { useState, useEffect } from 'react';
import { Button } from '../ui/button';
import { X, CreditCard, AlertCircle } from 'lucide-react';
import { createSubscription, createTrialSubscription } from '../../lib/subscriptions';
import { getTenantPlans } from '../../lib/membership';
import { MembershipPlan } from '../../types';
import { formatCurrency } from '../../lib/utils';
import { TenantSelector } from '../users/TenantSelector';
import { UserSelector } from '../users/UserSelector';

interface CreateSubscriptionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function CreateSubscriptionModal({
  isOpen,
  onClose,
  onSuccess,
}: CreateSubscriptionModalProps) {
  const [formData, setFormData] = useState({
    userId: '',
    planId: '',
    tenantId: '',
    startTrial: false,
  });

  const [plans, setPlans] = useState<MembershipPlan[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (formData.tenantId) {
      fetchPlans();
    }
  }, [formData.tenantId]);

  async function fetchPlans() {
    try {
      const data = await getTenantPlans(formData.tenantId);
      setPlans(data.filter(plan => plan.is_active));
    } catch (error) {
      console.error('Error fetching plans:', error);
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      if (formData.startTrial) {
        await createTrialSubscription(formData.userId, formData.planId);
      } else {
        await createSubscription(formData.userId, formData.planId);
      }
      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create subscription');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  const selectedPlan = plans.find(p => p.id === formData.planId);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">
            Create New Subscription
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
              Tenant
            </label>
            <TenantSelector
              value={formData.tenantId}
              onChange={(tenantId) => setFormData({ ...formData, tenantId })}
              className="mt-1"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">
              User
            </label>
            <UserSelector
              tenantId={formData.tenantId}
              value={formData.userId}
              onChange={(userId) => setFormData({ ...formData, userId })}
              className="mt-1"
            />
          </div>

          {plans.length > 0 && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Select Plan
              </label>
              <div className="space-y-2">
                {plans.map(plan => (
                  <div
                    key={plan.id}
                    className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                      plan.id === formData.planId
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-blue-300'
                    }`}
                    onClick={() => setFormData({ ...formData, planId: plan.id })}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <div className="font-medium text-gray-900">{plan.name}</div>
                        <div className="text-sm text-gray-500">{plan.description}</div>
                      </div>
                      <div className="text-lg font-semibold text-gray-900">
                        {formatCurrency(plan.price)}
                        <span className="text-sm font-normal text-gray-500">
                          /{plan.interval}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {selectedPlan?.trial_days > 0 && (
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="startTrial"
                className="h-4 w-4 text-blue-600 rounded border-gray-300"
                checked={formData.startTrial}
                onChange={(e) => setFormData({ ...formData, startTrial: e.target.checked })}
              />
              <label htmlFor="startTrial" className="text-sm text-gray-700">
                Start with {selectedPlan.trial_days}-day trial period
              </label>
            </div>
          )}

          {error && (
            <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
              <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
              <p className="text-sm text-red-600">{error}</p>
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
              disabled={isLoading || !formData.userId || !formData.planId}
              className="inline-flex items-center"
            >
              {isLoading ? (
                <>Loading...</>
              ) : (
                <>
                  <CreditCard className="h-4 w-4 mr-2" />
                  Create Subscription
                </>
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}