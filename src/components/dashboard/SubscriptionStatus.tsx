import React from 'react';
import { PieChart } from 'lucide-react';

interface SubscriptionStatusProps {
  data: {
    active: number;
    canceled: number;
    pastDue: number;
  };
}

export function SubscriptionStatus({ data }: SubscriptionStatusProps) {
  const total = data.active + data.canceled + data.pastDue;
  const activePercent = Math.round((data.active / total) * 100);
  const canceledPercent = Math.round((data.canceled / total) * 100);
  const pastDuePercent = Math.round((data.pastDue / total) * 100);

  return (
    <div className="bg-white rounded-lg shadow-sm p-6">
      <div className="flex items-center gap-2 mb-4">
        <PieChart className="h-5 w-5 text-blue-600" />
        <h3 className="text-lg font-semibold text-gray-900">
          Subscription Status
        </h3>
      </div>

      <div className="flex items-center justify-between mb-6">
        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-green-500" />
            <span className="text-sm text-gray-600">Active</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-red-500" />
            <span className="text-sm text-gray-600">Canceled</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-yellow-500" />
            <span className="text-sm text-gray-600">Past Due</span>
          </div>
        </div>

        <div className="relative w-32 h-32">
          <svg className="w-full h-full" viewBox="0 0 36 36">
            {/* Active segment */}
            <path
              d={`M18 2
                a 16 16 0 0 1 0 32
                a 16 16 0 0 1 0 -32`}
              className="fill-green-500"
            />
            {/* Canceled segment */}
            <path
              d={`M18 2
                a 16 16 0 0 1 ${16 * Math.cos((activePercent / 100) * Math.PI * 2)} ${16 * Math.sin((activePercent / 100) * Math.PI * 2)}
                a 16 16 0 0 1 ${-16 * Math.cos((canceledPercent / 100) * Math.PI * 2)} ${-16 * Math.sin((canceledPercent / 100) * Math.PI * 2)}
                Z`}
              className="fill-red-500"
              transform={`rotate(${activePercent * 3.6} 18 18)`}
            />
            {/* Past Due segment */}
            <path
              d={`M18 2
                a 16 16 0 0 1 ${16 * Math.cos((pastDuePercent / 100) * Math.PI * 2)} ${16 * Math.sin((pastDuePercent / 100) * Math.PI * 2)}
                a 16 16 0 0 1 ${-16 * Math.cos((pastDuePercent / 100) * Math.PI * 2)} ${-16 * Math.sin((pastDuePercent / 100) * Math.PI * 2)}
                Z`}
              className="fill-yellow-500"
              transform={`rotate(${(activePercent + canceledPercent) * 3.6} 18 18)`}
            />
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{total}</div>
              <div className="text-xs text-gray-500">Total</div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4 text-center">
        <div>
          <div className="text-lg font-semibold text-gray-900">{activePercent}%</div>
          <div className="text-sm text-gray-500">Active</div>
        </div>
        <div>
          <div className="text-lg font-semibold text-gray-900">{canceledPercent}%</div>
          <div className="text-sm text-gray-500">Canceled</div>
        </div>
        <div>
          <div className="text-lg font-semibold text-gray-900">{pastDuePercent}%</div>
          <div className="text-sm text-gray-500">Past Due</div>
        </div>
      </div>
    </div>
  );
}