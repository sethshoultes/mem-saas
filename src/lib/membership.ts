import { supabase } from './supabase';
import { MembershipPlan, MemberSubscription } from '../types';

export async function createMembershipPlan(
  name: string,
  description: string | null,
  price: number,
  interval: 'monthly' | 'yearly',
  trial_days: number,
  features: string[]
): Promise<string> {
  const { data, error } = await supabase.rpc('create_membership_plan', {
    p_name: name,
    p_description: description,
    p_price: price,
    p_interval: interval,
    p_trial_days: trial_days,
    p_features: features
  });

  if (error) throw error;
  return data;
}

export async function updateMembershipPlan(
  planId: string,
  updates: Partial<MembershipPlan>
): Promise<boolean> {
  const { data, error } = await supabase.rpc('update_membership_plan', {
    p_plan_id: planId,
    p_name: updates.name,
    p_description: updates.description,
    p_price: updates.price,
    p_interval: updates.interval,
    p_features: updates.features,
    p_is_active: updates.is_active
  });

  if (error) throw error;
  return data;
}

export async function getTenantPlans(tenantId: string): Promise<MembershipPlan[]> {
  const { data, error } = await supabase
    .rpc('get_tenant_plans', { p_tenant_id: tenantId });

  if (error) throw error;
  return data;
}

export async function getPlanSubscriptions(planId: string) {
  const { data, error } = await supabase
    .rpc('get_plan_subscriptions', { p_plan_id: planId });

  if (error) throw error;
  return data;
}

export async function manageSubscription(
  subscriptionId: string,
  action: 'cancel' | 'reactivate'
): Promise<boolean> {
  const { data, error } = await supabase.rpc('manage_subscription', {
    p_subscription_id: subscriptionId,
    p_action: action
  });

  if (error) throw error;
  return data;
}