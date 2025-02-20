import { supabase } from './supabase';

export async function createSubscription(
  userId: string,
  planId: string,
  stripeSubscriptionId?: string
) {
  const { data, error } = await supabase
    .rpc('create_subscription', {
      p_user_id: userId,
      p_plan_id: planId,
      p_stripe_subscription_id: stripeSubscriptionId
    });

  if (error) throw error;
  return data;
}

export async function updateSubscriptionStatus(
  subscriptionId: string,
  status: 'active' | 'canceled' | 'past_due',
  cancelAtPeriodEnd: boolean = false
) {
  const { data, error } = await supabase
    .rpc('update_subscription_status', {
      p_subscription_id: subscriptionId,
      p_status: status,
      p_cancel_at_period_end: cancelAtPeriodEnd
    });

  if (error) throw error;
  return data;
}

export async function getUserSubscriptions(userId: string) {
  const { data, error } = await supabase
    .rpc('get_user_subscriptions', {
      p_user_id: userId
    });

  if (error) throw error;
  return data;
}

export async function getTenantSubscriptions(tenantId: string) {
  const { data, error } = await supabase
    .rpc('get_tenant_subscriptions', {
      p_tenant_id: tenantId
    });

  if (error) throw error;
  return data;
}

export async function processSubscriptionRenewal(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('process_subscription_renewal', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}

export async function cancelSubscription(
  subscriptionId: string,
  immediate: boolean = false
) {
  const { data, error } = await supabase
    .rpc('cancel_subscription', {
      p_subscription_id: subscriptionId,
      p_immediate: immediate
    });

  if (error) throw error;
  return data;
}

export async function reactivateSubscription(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('reactivate_subscription', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}

export async function retrySubscriptionPayment(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('retry_subscription_payment', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}

export async function getSubscriptionDetails(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('get_subscription_details', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}

export async function upgradeSubscription(
  subscriptionId: string,
  newPlanId: string,
  immediate: boolean = true
) {
  const { data, error } = await supabase
    .rpc('upgrade_subscription', {
      p_subscription_id: subscriptionId,
      p_new_plan_id: newPlanId,
      p_immediate: immediate
    });

  if (error) throw error;
  return data;
}

export async function downgradeSubscription(
  subscriptionId: string,
  newPlanId: string
) {
  const { data, error } = await supabase
    .rpc('downgrade_subscription', {
      p_subscription_id: subscriptionId,
      p_new_plan_id: newPlanId
    });

  if (error) throw error;
  return data;
}

export async function getSubscriptionChanges(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('get_subscription_changes', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}