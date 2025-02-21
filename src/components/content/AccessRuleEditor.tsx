import React, { useState, useEffect } from 'react';
import { Button } from '../ui/button';
import { AlertCircle, Plus, Trash2, Shield } from 'lucide-react';
import { AccessRule, createAccessRule, deleteAccessRule, getContentAccess } from '../../lib/access-control';
import { MembershipPlan } from '../../types';
import { getTenantPlans } from '../../lib/membership';
import { useAdminStore } from '../../store';

interface AccessRuleEditorProps {
  contentId: string;
  onUpdate?: () => void;
}

export function AccessRuleEditor({ contentId, onUpdate }: AccessRuleEditorProps) {
  const [rules, setRules] = useState<AccessRule[]>([]);
  const [plans, setPlans] = useState<MembershipPlan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedPlan, setSelectedPlan] = useState<string>('');
  const [selectedAccess, setSelectedAccess] = useState<'full' | 'preview'>('full');
  const { currentUser } = useAdminStore();

  useEffect(() => {
    if (currentUser?.profile?.tenant_id) {
      fetchData();
    }
  }, [currentUser]);

  const fetchData = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const [accessRules, membershipPlans] = await Promise.all([
        getContentAccess(contentId),
        getTenantPlans(currentUser!.profile!.tenant_id!)
      ]);

      setRules(accessRules);
      setPlans(membershipPlans);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load access rules');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddRule = async () => {
    if (!selectedPlan) return;

    try {
      await createAccessRule(contentId, selectedPlan, selectedAccess);
      fetchData();
      onUpdate?.();
      setSelectedPlan('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create access rule');
    }
  };

  const handleDeleteRule = async (ruleId: string) => {
    try {
      await deleteAccessRule(ruleId);
      fetchData();
      onUpdate?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete access rule');
    }
  };

  if (isLoading) {
    return <div className="text-center p-4">Loading access rules...</div>;
  }

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-gray-900">Access Rules</h3>
        <p className="text-sm text-gray-500">
          Define which membership plans can access this content
        </p>
      </div>

      <div className="space-y-4">
        {rules.map(rule => {
          const plan = plans.find(p => p.id === rule.plan_id);
          return (
            <div
              key={rule.id}
              className="flex items-center justify-between p-4 bg-white rounded-lg border border-gray-200"
            >
              <div className="flex items-center gap-3">
                <Shield className={`h-5 w-5 ${
                  rule.access_type === 'full' ? 'text-green-500' : 'text-yellow-500'
                }`} />
                <div>
                  <div className="font-medium text-gray-900">
                    {plan?.name || 'Unknown Plan'}
                  </div>
                  <div className="text-sm text-gray-500">
                    {rule.access_type === 'full' ? 'Full Access' : 'Preview Access'}
                  </div>
                </div>
              </div>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => handleDeleteRule(rule.id)}
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          );
        })}
      </div>

      <div className="p-4 bg-gray-50 rounded-lg space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Membership Plan
            </label>
            <select
              className="w-full rounded-md border border-gray-300 px-3 py-2"
              value={selectedPlan}
              onChange={(e) => setSelectedPlan(e.target.value)}
            >
              <option value="">Select a plan...</option>
              {plans.map(plan => (
                <option key={plan.id} value={plan.id}>
                  {plan.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Access Type
            </label>
            <select
              className="w-full rounded-md border border-gray-300 px-3 py-2"
              value={selectedAccess}
              onChange={(e) => setSelectedAccess(e.target.value as 'full' | 'preview')}
            >
              <option value="full">Full Access</option>
              <option value="preview">Preview Access</option>
            </select>
          </div>
        </div>

        <Button
          onClick={handleAddRule}
          disabled={!selectedPlan}
          className="w-full"
        >
          <Plus className="h-4 w-4 mr-2" />
          Add Access Rule
        </Button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}
    </div>
  );
}