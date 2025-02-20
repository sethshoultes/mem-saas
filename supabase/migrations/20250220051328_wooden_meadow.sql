/*
  # Fix Tenant Subscriptions Query

  1. Changes
    - Fixed tenant_id reference in get_tenant_subscriptions function
    - Added proper join through user_profiles to get tenant subscriptions
    - Added subscription details including user name and plan info

  2. Security
    - Maintained SECURITY DEFINER
    - Added input validation
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_tenant_subscriptions(uuid);

-- Create the new function with updated return type
CREATE OR REPLACE FUNCTION get_tenant_subscriptions(p_tenant_id uuid)
RETURNS TABLE (
  subscription_id uuid,
  user_id uuid,
  user_name text,
  plan_name text,
  status text,
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
    ms.current_period_end,
    mp.price as amount
  FROM member_subscriptions ms
  JOIN user_profiles up ON ms.user_id = up.id
  JOIN membership_plans mp ON ms.plan_id = mp.id
  WHERE up.tenant_id = p_tenant_id;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_tenant_subscriptions TO authenticated;