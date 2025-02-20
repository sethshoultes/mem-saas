/*
  # Update subscription list function to include trial information

  1. Changes
    - Drop existing function to allow return type change
    - Recreate function with trial information
    - Enhanced subscription status tracking

  2. Security
    - Maintains existing security model
    - No changes to RLS policies
*/

-- First drop the existing function
DROP FUNCTION IF EXISTS get_tenant_subscriptions(uuid);

-- Recreate the function with updated return type
CREATE OR REPLACE FUNCTION get_tenant_subscriptions(p_tenant_id uuid)
RETURNS TABLE (
  subscription_id uuid,
  user_id uuid,
  user_name text,
  plan_name text,
  status text,
  is_trial boolean,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  amount decimal
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT 
    ms.id as subscription_id,
    ms.user_id,
    up.full_name as user_name,
    mp.name as plan_name,
    ms.status,
    ms.is_trial,
    ms.trial_ends_at,
    ms.current_period_end,
    mp.price as amount
  FROM member_subscriptions ms
  JOIN user_profiles up ON ms.user_id = up.id
  JOIN membership_plans mp ON ms.plan_id = mp.id
  WHERE up.tenant_id = p_tenant_id;
$$;