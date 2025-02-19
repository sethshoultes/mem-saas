import { supabase } from './supabase';
import { DashboardMetrics, ChartData } from '../types';

export async function getDashboardStats(): Promise<DashboardMetrics> {
  const { data, error } = await supabase
    .rpc('get_dashboard_stats');

  if (error) {
    throw error;
  }

  return data;
}

export async function getRevenueData(): Promise<ChartData> {
  const { data, error } = await supabase
    .rpc('get_revenue_data');

  if (error) {
    throw error;
  }

  return {
    labels: data.map(d => d.month),
    datasets: [{
      label: 'Revenue',
      data: data.map(d => d.amount),
      backgroundColor: Array(data.length).fill('#3B82F6'),
    }],
  };
}

export async function getSubscriptionDistribution() {
  const { data, error } = await supabase
    .rpc('get_subscription_distribution');

  if (error) {
    throw error;
  }

  return {
    active: data.active || 0,
    canceled: data.canceled || 0,
    pastDue: data.past_due || 0,
  };
}