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

export async function createTrialSubscription(
  userId: string,
  planId: string
) {
  const { data, error } = await supabase
    .rpc('create_trial_subscription', {
      p_user_id: userId,
      p_plan_id: planId
    });

  if (error) throw error;
  return data;
}

export async function processTrialExpiration(
  subscriptionId: string,
  convertToPaid: boolean = false
): Promise<void> {
  const { data, error } = await supabase
    .rpc('process_trial_expiration', {
      p_subscription_id: subscriptionId,
      p_convert_to_paid: convertToPaid
    });

  if (error) throw error;
}

export async function getTrialStatus(subscriptionId: string) {
  const { data, error } = await supabase
    .rpc('get_trial_status', {
      p_subscription_id: subscriptionId
    });

  if (error) throw error;
  return data;
}

export async function bulkUpdateSubscriptionStatus(
  subscriptionIds: string[],
  status: 'active' | 'canceled' | 'past_due',
  immediate: boolean = false
) {
  const { data, error } = await supabase
    .rpc('bulk_update_subscription_status', {
      p_subscription_ids: subscriptionIds,
      p_status: status,
      p_immediate: immediate
    });

  if (error) throw error;
  return data;
}

export async function bulkConvertTrials(subscriptionIds: string[]) {
  const { data, error } = await supabase
    .rpc('bulk_convert_trials', {
      p_subscription_ids: subscriptionIds
    });

  if (error) throw error;
  return data;
}

export async function bulkCancelSubscriptions(
  subscriptionIds: string[],
  immediate: boolean = false
) {
  const { data, error } = await supabase
    .rpc('bulk_cancel_subscriptions', {
      p_subscription_ids: subscriptionIds,
      p_immediate: immediate
    });

  if (error) throw error;
  return data;
}

export async function getBulkOperationStatus(operationId: string) {
  const { data, error } = await supabase
    .rpc('get_bulk_operation_status', {
      p_operation_id: operationId
    });

  if (error) throw error;
  return data;
}