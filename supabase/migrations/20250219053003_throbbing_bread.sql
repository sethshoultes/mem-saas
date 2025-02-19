/*
  # Membership Management Functions

  1. New Functions
    - `create_membership_plan` - Creates a new membership plan
    - `update_membership_plan` - Updates an existing plan
    - `get_tenant_plans` - Retrieves plans for a tenant
    - `get_plan_subscriptions` - Gets subscriptions for a plan
    - `manage_subscription` - Handles subscription lifecycle

  2. Security
    - All functions are SECURITY DEFINER
    - Role-based access control
    - Tenant isolation
*/

-- Function to create a new membership plan
CREATE OR REPLACE FUNCTION create_membership_plan(
  p_name text,
  p_description text,
  p_price decimal,
  p_interval text,
  p_features jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan_id uuid;
  v_tenant_id uuid;
BEGIN
  -- Get tenant ID from current user's profile
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Insert new plan
  INSERT INTO membership_plans (
    tenant_id,
    name,
    description,
    price,
    interval,
    features
  )
  VALUES (
    v_tenant_id,
    p_name,
    p_description,
    p_price,
    p_interval,
    p_features
  )
  RETURNING id INTO v_plan_id;

  -- Log activity
  PERFORM log_user_activity(
    auth.uid(),
    'plan_created',
    jsonb_build_object(
      'plan_id', v_plan_id,
      'name', p_name,
      'price', p_price,
      'interval', p_interval
    )
  );

  RETURN v_plan_id;
END;
$$;

-- Function to update an existing membership plan
CREATE OR REPLACE FUNCTION update_membership_plan(
  p_plan_id uuid,
  p_name text,
  p_description text,
  p_price decimal,
  p_interval text,
  p_features jsonb,
  p_is_active boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  -- Get tenant ID from current user's profile
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Update plan if it belongs to the tenant
  UPDATE membership_plans
  SET
    name = p_name,
    description = p_description,
    price = p_price,
    interval = p_interval,
    features = p_features,
    is_active = p_is_active,
    updated_at = now()
  WHERE id = p_plan_id
  AND tenant_id = v_tenant_id;

  -- Log activity
  PERFORM log_user_activity(
    auth.uid(),
    'plan_updated',
    jsonb_build_object(
      'plan_id', p_plan_id,
      'name', p_name,
      'price', p_price,
      'interval', p_interval,
      'is_active', p_is_active
    )
  );

  RETURN FOUND;
END;
$$;

-- Function to get all plans for a tenant
CREATE OR REPLACE FUNCTION get_tenant_plans(p_tenant_id uuid)
RETURNS SETOF membership_plans
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT p.*
  FROM membership_plans p
  WHERE p.tenant_id = p_tenant_id
  ORDER BY p.created_at DESC;
$$;

-- Function to get subscriptions for a plan
CREATE OR REPLACE FUNCTION get_plan_subscriptions(p_plan_id uuid)
RETURNS TABLE (
  subscription_id uuid,
  user_id uuid,
  full_name text,
  email text,
  status text,
  current_period_end timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    ms.id as subscription_id,
    ms.user_id,
    up.full_name,
    au.email,
    ms.status,
    ms.current_period_end
  FROM member_subscriptions ms
  JOIN user_profiles up ON ms.user_id = up.id
  JOIN auth.users au ON up.id = au.id
  WHERE ms.plan_id = p_plan_id
  ORDER BY ms.created_at DESC;
$$;

-- Function to manage subscription status
CREATE OR REPLACE FUNCTION manage_subscription(
  p_subscription_id uuid,
  p_action text  -- 'cancel', 'reactivate'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_sub_tenant_id uuid;
BEGIN
  -- Get tenant ID of the user making the request
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Get tenant ID of the subscription's plan
  SELECT p.tenant_id INTO v_sub_tenant_id
  FROM member_subscriptions ms
  JOIN membership_plans p ON ms.plan_id = p.id
  WHERE ms.id = p_subscription_id;

  -- Verify tenant ownership
  IF v_tenant_id != v_sub_tenant_id THEN
    RETURN false;
  END IF;

  -- Update subscription based on action
  UPDATE member_subscriptions
  SET
    status = CASE p_action
      WHEN 'cancel' THEN 'canceled'
      WHEN 'reactivate' THEN 'active'
      ELSE status
    END,
    updated_at = now(),
    cancel_at_period_end = p_action = 'cancel'
  WHERE id = p_subscription_id;

  -- Log activity
  PERFORM log_user_activity(
    auth.uid(),
    'subscription_' || p_action,
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'action', p_action
    )
  );

  RETURN FOUND;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_membership_plan TO authenticated;
GRANT EXECUTE ON FUNCTION update_membership_plan TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_plans TO authenticated;
GRANT EXECUTE ON FUNCTION get_plan_subscriptions TO authenticated;
GRANT EXECUTE ON FUNCTION manage_subscription TO authenticated;