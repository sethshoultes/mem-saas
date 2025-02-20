import React from 'react';
import { MembershipPlan } from '../../types';
import { Button } from '../ui/button';
import { formatCurrency } from '../../lib/utils';
import { Check } from 'lucide-react';

interface MembershipPlanCardProps {
  plan: MembershipPlan;
  onEdit: (plan: MembershipPlan) => void;
  onDelete: (plan: MembershipPlan) => void;
}

export function MembershipPlanCard({ plan, onEdit, onDelete }: MembershipPlanCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 flex flex-col">
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">{plan.name}</h3>
          <p className="text-sm text-gray-500">{plan.description}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => onEdit(plan)}
          >
            Edit
          </Button>
          <Button
            variant="danger"
            size="sm"
            onClick={() => onDelete(plan)}
          >
            Delete
          </Button>
        </div>
      </div>
      
      <div className="mb-4">
        <div className="text-2xl font-bold text-gray-900">
          {formatCurrency(plan.price)}
          <div className="text-sm font-normal text-gray-500">
            per {plan.interval}
            {plan.trial_days > 0 && (
              <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                {plan.trial_days}-day trial
              </span>
            )}
          </div>
        </div>
      </div>
      
      <div className="flex-grow">
        <h4 className="text-sm font-medium text-gray-900 mb-2">Features:</h4>
        <ul className="space-y-2">
          {plan.features.map((feature, index) => (
            <li key={index} className="flex items-center text-sm text-gray-600">
              <Check className="h-4 w-4 text-green-500 mr-2 flex-shrink-0" />
              {feature}
            </li>
          ))}
        </ul>
      </div>
      
      <div className="mt-4 pt-4 border-t border-gray-200">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-500">Status:</span>
          <span className={`font-medium ${plan.is_active ? 'text-green-600' : 'text-red-600'}`}>
            {plan.is_active ? 'Active' : 'Inactive'}
          </span>
        </div>
      </div>
    </div>
  );
}