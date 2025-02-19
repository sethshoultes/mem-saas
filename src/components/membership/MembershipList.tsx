import React, { useEffect, useState } from 'react';
import { MembershipPlan } from '../../types';
import { getTenantPlans } from '../../lib/membership';
import { MembershipPlanCard } from './MembershipPlanCard';
import { Button } from '../ui/button';
import { Plus } from 'lucide-react';
import { MembershipModal } from './MembershipModal';
import { useAdminStore } from '../../store';

export function MembershipList() {
  const [plans, setPlans] = useState<MembershipPlan[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState<MembershipPlan | undefined>();
  const { currentUser } = useAdminStore();

  useEffect(() => {
    if (currentUser?.profile?.tenant_id) {
      fetchPlans();
    }
  }, [currentUser]);

  async function fetchPlans() {
    if (!currentUser?.profile?.tenant_id) return;
    
    try {
      const plans = await getTenantPlans(currentUser.profile.tenant_id);
      setPlans(plans);
    } catch (error) {
      console.error('Error fetching plans:', error);
    } finally {
      setIsLoading(false);
    }
  }

  if (isLoading) {
    return <div className="flex justify-center p-8">Loading plans...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Membership Plans</h1>
        <Button onClick={() => {
          setSelectedPlan(undefined);
          setIsModalOpen(true);
        }}>
          <Plus className="h-4 w-4 mr-2" />
          Add Plan
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {plans.map(plan => (
          <MembershipPlanCard
            key={plan.id}
            plan={plan}
            onEdit={() => {
              setSelectedPlan(plan);
              setIsModalOpen(true);
            }}
            onDelete={async () => {
              if (confirm('Are you sure you want to delete this plan?')) {
                try {
                  await updateMembershipPlan(plan.id, { is_active: false });
                  fetchPlans();
                } catch (error) {
                  console.error('Error deleting plan:', error);
                }
              }
            }}
          />
        ))}
      </div>

      <MembershipModal
        plan={selectedPlan}
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false);
          setSelectedPlan(undefined);
        }}
        onSuccess={fetchPlans}
      />
    </div>
  );
}