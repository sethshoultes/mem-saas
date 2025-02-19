import React from 'react';
import { BarChart3, Users, Building2, CreditCard } from 'lucide-react';
import { DashboardMetrics } from '../../types';
import { formatCurrency } from '../../lib/utils';

interface StatsCardProps {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

function StatsCard({ title, value, icon, trend }: StatsCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-sm p-6">
      <div className="flex items-center justify-between">
        <div className="p-2 bg-blue-50 rounded-lg">
          {icon}
        </div>
        {trend && (
          <span className={`text-sm font-medium ${
            trend.isPositive ? 'text-green-600' : 'text-red-600'
          }`}>
            {trend.isPositive ? '+' : '-'}{trend.value}%
          </span>
        )}
      </div>
      <h3 className="mt-4 text-2xl font-semibold text-gray-900">
        {value}
      </h3>
      <p className="text-sm text-gray-500">{title}</p>
    </div>
  );
}

interface DashboardStatsProps {
  stats: DashboardMetrics;
}

export function DashboardStats({ stats }: DashboardStatsProps) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <StatsCard
        title="Active Users"
        value={stats.total_users}
        icon={<Users className="h-6 w-6 text-blue-600" />}
        trend={{ value: 12, isPositive: true }}
      />
      <StatsCard
        title="Active Tenants"
        value={stats.active_tenants}
        icon={<Building2 className="h-6 w-6 text-blue-600" />}
        trend={{ value: 8, isPositive: true }}
      />
      <StatsCard
        title="Monthly Revenue"
        value={formatCurrency(stats.monthly_revenue)}
        icon={<CreditCard className="h-6 w-6 text-blue-600" />}
        trend={{ value: 15, isPositive: true }}
      />
      <StatsCard
        title="Active Subscriptions"
        value={stats.active_subscriptions}
        icon={<BarChart3 className="h-6 w-6 text-blue-600" />}
        trend={{ value: 5, isPositive: true }}
      />
    </div>
  );
}