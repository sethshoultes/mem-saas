import React, { useState, useEffect } from 'react';
import { Button } from '../ui/button';
import { X, ArrowUpDown, AlertCircle, Loader2 } from 'lucide-react';
import { getTenantPlans } from '../../lib/membership';
import { MembershipPlan } from '../../types';
import { formatCurrency } from '../../lib/utils';
import { upgradeSubscription, downgradeSubscription } from '../../lib/subscriptions';
import { useAdminStore } from '../../store';

interface UpgradeSubscriptionModalProps {
  subscription: Subscription | null;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function UpgradeSubscriptionModal({
  subscription,
  isOpen,
  onClose,
  onSuccess,
}: UpgradeSubscriptionModalProps) {
  const [plans, setPlans] = useState<MembershipPlan[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState<string>('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isImmediate, setIsImmediate] = useState<boolean>(true);
  const { currentUser } = useAdminStore();

  useEffect(() => {
    if (subscription) {
      setSelectedPlanId('');
      setError(null);
    }
  }, [subscription]);

  useEffect(() => {
    if (currentUser?.profile?.tenant_id) {
      fetchPlans();
    }
  }, [currentUser]);

  async function fetchPlans() {
    if (!currentUser?.profile?.tenant_id) return;
    
    try {
      const plans = await getTenantPlans(currentUser.profile.tenant_id);
      setPlans(plans.filter(p => p.is_active));
    } catch (error) {
      console.error('Error fetching plans:', error);
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!subscription || !selectedPlanId) return;

    setIsLoading(true);
    setError(null);

    try {
      const selectedPlan = plans.find(p => p.id === selectedPlanId)!;
      const currentPlan = plans.find(p => p.id === subscription.plan_id) || {
        price: subscription.amount
      };

      if (selectedPlan.price > currentPlan.price) {
        await upgradeSubscription(subscription.subscription_id, selectedPlanId, isImmediate);
      } else {
        await downgradeSubscription(subscription.subscription_id, selectedPlanId);
      }

      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to change subscription plan');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen || !subscription) return null;

  const currentPlan = plans.find(p => p.id === subscription.plan_id) || {
    id: subscription.plan_id,
    name: subscription.plan_name,
    price: subscription.amount,
    interval: 'monthly'
  };

  const availablePlans = plans.filter(plan => plan.id !== currentPlan.id);
  const selectedPlan = plans.find(p => p.id === selectedPlanId);
  const isUpgrade = selectedPlan && selectedPlan.price > currentPlan.price;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">
            Change Subscription Plan
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
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Current Plan
            </label>
            <div className="p-3 bg-gray-50 rounded-lg">
              <div className="font-medium text-gray-900">{currentPlan?.name}</div>
              <div className="text-sm text-gray-500">
                {formatCurrency(currentPlan?.price || 0)}/{currentPlan?.interval}
              </div>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select New Plan
              {availablePlans.length === 0 && (
                <span className="text-sm text-gray-500 ml-2">
                  (No other plans available)
                </span>
              )}
            </label>
            <div className="space-y-2">
              {availablePlans
                .map(plan => (
                  <div
                    key={plan.id}
                    className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                      plan.id === selectedPlanId
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-blue-300'
                    }`}
                    onClick={() => setSelectedPlanId(plan.id)}
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

          {selectedPlanId && isUpgrade && (
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="immediate"
                className="h-4 w-4 text-blue-600 rounded border-gray-300"
                checked={isImmediate}
                onChange={(e) => setIsImmediate(e.target.checked)}
              />
              <label htmlFor="immediate" className="text-sm text-gray-700">
                Apply changes immediately
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
              disabled={isLoading || !selectedPlanId}
              className={`inline-flex items-center ${
                isUpgrade ? 'bg-blue-600' : 'bg-yellow-600'
              }`}
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Processing...
                </>
              ) : (
                <>
                  <ArrowUpDown className="h-4 w-4 mr-2" />
                  {isUpgrade ? 'Upgrade Plan' : 'Downgrade Plan'}
                </>
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}