import { supabase } from './supabase';

export interface AccessRule {
  id: string;
  content_id: string;
  plan_id: string;
  access_type: 'full' | 'preview';
  created_at: string;
}

export async function createAccessRule(
  contentId: string,
  planId: string,
  accessType: 'full' | 'preview' = 'full'
): Promise<AccessRule> {
  const { data, error } = await supabase
    .from('content_access')
    .insert({
      content_id: contentId,
      plan_id: planId,
      access_type: accessType
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function getContentAccess(contentId: string): Promise<AccessRule[]> {
  const { data, error } = await supabase
    .from('content_access')
    .select(`
      id,
      content_id,
      plan_id,
      access_type,
      created_at
    `)
    .eq('content_id', contentId);

  if (error) throw error;
  return data;
}

export async function updateAccessRule(
  ruleId: string,
  updates: Partial<AccessRule>
): Promise<AccessRule> {
  const { data, error } = await supabase
    .from('content_access')
    .update(updates)
    .eq('id', ruleId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteAccessRule(ruleId: string): Promise<void> {
  const { error } = await supabase
    .from('content_access')
    .delete()
    .eq('id', ruleId);

  if (error) throw error;
}

export async function verifyAccess(
  contentId: string,
  userId: string
): Promise<{
  hasAccess: boolean;
  accessType: 'full' | 'preview' | null;
}> {
  // Get user's active subscriptions
  const { data: subscriptions, error: subError } = await supabase
    .from('member_subscriptions')
    .select('plan_id')
    .eq('user_id', userId)
    .eq('status', 'active');

  if (subError) throw subError;

  if (!subscriptions.length) {
    return { hasAccess: false, accessType: null };
  }

  // Check content access rules
  const { data: accessRules, error: accessError } = await supabase
    .from('content_access')
    .select('access_type')
    .eq('content_id', contentId)
    .in('plan_id', subscriptions.map(s => s.plan_id));

  if (accessError) throw accessError;

  if (!accessRules.length) {
    return { hasAccess: false, accessType: null };
  }

  // Return highest level of access (full > preview)
  const hasFullAccess = accessRules.some(rule => rule.access_type === 'full');
  return {
    hasAccess: true,
    accessType: hasFullAccess ? 'full' : 'preview'
  };
}

export async function getContentPreview(contentId: string): Promise<string | null> {
  const { data, error } = await supabase
    .from('content_items')
    .select('preview_content')
    .eq('id', contentId)
    .single();

  if (error) throw error;
  return data?.preview_content || null;
}