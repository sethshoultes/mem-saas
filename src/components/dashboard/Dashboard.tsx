import React, { useEffect, useState } from 'react';
import { DashboardStats } from './DashboardStats';
import { RevenueChart } from './RevenueChart';
import { SubscriptionStatus } from './SubscriptionStatus';
import { supabase } from '../../lib/supabase';
import { DashboardMetrics, ChartData } from '../../types';

export function Dashboard() {
  const [stats, setStats] = useState<DashboardMetrics>({
    total_users: 0,
    active_tenants: 0,
    monthly_revenue: 0,
    active_subscriptions: 0,
  });

  const [revenueData, setRevenueData] = useState<ChartData>({
    labels: [],
    datasets: [{
      label: 'Revenue',
      data: [],
      backgroundColor: [],
    }],
  });

  const [subscriptionStatus, setSubscriptionStatus] = useState({
    active: 0,
    canceled: 0,
    pastDue: 0,
  });

  useEffect(() => {
    fetchDashboardData();
  }, []);

  async function fetchDashboardData() {
    try {
      // Fetch overview statistics
      const { data: statsData, error: statsError } = await supabase
        .rpc('get_dashboard_stats');

      if (statsError) throw statsError;

      // Fetch revenue data for the chart
      const { data: revenueData, error: revenueError } = await supabase
        .rpc('get_revenue_data');

      if (revenueError) throw revenueError;

      // Fetch subscription status distribution
      const { data: subscriptionData, error: subscriptionError } = await supabase
        .rpc('get_subscription_distribution');

      if (subscriptionError) throw subscriptionError;

      // Update state with fetched data
      if (statsData) {
        setStats(statsData);
      }

      if (revenueData) {
        setRevenueData({
          labels: revenueData.map(d => d.month),
          datasets: [{
            label: 'Revenue',
            data: revenueData.map(d => d.amount),
            backgroundColor: Array(revenueData.length).fill('#3B82F6'),
          }],
        });
      }

      if (subscriptionData) {
        setSubscriptionStatus({
          active: subscriptionData.active || 0,
          canceled: subscriptionData.canceled || 0,
          pastDue: subscriptionData.past_due || 0,
        });
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
      </div>

      <DashboardStats stats={stats} />

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <RevenueChart data={revenueData} />
        <SubscriptionStatus data={subscriptionStatus} />
      </div>
    </div>
  );
}