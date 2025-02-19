/*
  # Subscription Management Implementation

  1. New Functions
    - create_subscription: Creates a new subscription for a user
    - update_subscription: Updates subscription status and details
    - get_user_subscriptions: Retrieves subscriptions for a user
    - get_tenant_subscriptions: Retrieves all subscriptions for a tenant
    - process_subscription_renewal: Handles subscription renewal logic

  2. Changes
    - Added subscription management functions
    - Added subscription status tracking
    - Added renewal processing
*/

-- Function to create a new subscription
CREATE OR REPLACE FUNCTION create_subscription(
  p_user_id uuid,
  p_plan_id uuid,
  p_stripe_subscription_id text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription_id uuid;
BEGIN
  INSERT INTO member_subscriptions (
    user_id,
    plan_id,
    status,
    current_period_start,
    current_period_end,
    stripe_subscription_id
  )
  VALUES (
    p_user_id,
    p_plan_id,
    'active',
    now(),
    now() + interval '1 month',
    p_stripe_subscription_id
  )
  RETURNING id INTO v_subscription_id;

  -- Log activity
  PERFORM log_user_activity(
    p_user_id,
    'subscription_created',
    jsonb_build_object(
      'subscription_id', v_subscription_id,
      'plan_id', p_plan_id
    )
  );

  RETURN v_subscription_id;
END;
$$;

-- Function to update subscription status
CREATE OR REPLACE FUNCTION update_subscription_status(
  p_subscription_id uuid,
  p_status text,
  p_cancel_at_period_end boolean DEFAULT false
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE member_subscriptions
  SET
    status = p_status,
    cancel_at_period_end = p_cancel_at_period_end,
    updated_at = now()
  WHERE id = p_subscription_id;

  -- Log activity
  PERFORM log_user_activity(
    (SELECT user_id FROM member_subscriptions WHERE id = p_subscription_id),
    'subscription_updated',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'status', p_status,
      'cancel_at_period_end', p_cancel_at_period_end
    )
  );

  RETURN FOUND;
END;
$$;

-- Function to get user subscriptions
CREATE OR REPLACE FUNCTION get_user_subscriptions(p_user_id uuid)
RETURNS TABLE (
  subscription_id uuid,
  plan_id uuid,
  plan_name text,
  status text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean,
  price decimal,
  interval text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    ms.id as subscription_id,
    mp.id as plan_id,
    mp.name as plan_name,
    ms.status,
    ms.current_period_start,
    ms.current_period_end,
    ms.cancel_at_period_end,
    mp.price,
    mp.interval
  FROM member_subscriptions ms
  JOIN membership_plans mp ON ms.plan_id = mp.id
  WHERE ms.user_id = p_user_id
  ORDER BY ms.created_at DESC;
$$;

-- Function to get tenant subscriptions
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
    up.id as user_id,
    up.full_name as user_name,
    mp.name as plan_name,
    ms.status,
    ms.current_period_end,
    mp.price as amount
  FROM member_subscriptions ms
  JOIN membership_plans mp ON ms.plan_id = mp.id
  JOIN user_profiles up ON ms.user_id = up.id
  WHERE up.tenant_id = p_tenant_id
  ORDER BY ms.created_at DESC;
$$;

-- Function to process subscription renewals
CREATE OR REPLACE FUNCTION process_subscription_renewal(p_subscription_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription member_subscriptions;
BEGIN
  -- Get subscription details
  SELECT * INTO v_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;

  -- Check if subscription should be renewed
  IF v_subscription.status = 'active' AND NOT v_subscription.cancel_at_period_end THEN
    -- Update period
    UPDATE member_subscriptions
    SET
      current_period_start = current_period_end,
      current_period_end = current_period_end + 
        CASE (
          SELECT interval 
          FROM membership_plans 
          WHERE id = v_subscription.plan_id
        )
          WHEN 'monthly' THEN interval '1 month'
          WHEN 'yearly' THEN interval '1 year'
        END,
      updated_at = now()
    WHERE id = p_subscription_id;

    -- Log renewal
    PERFORM log_user_activity(
      v_subscription.user_id,
      'subscription_renewed',
      jsonb_build_object(
        'subscription_id', p_subscription_id,
        'plan_id', v_subscription.plan_id
      )
    );

    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION update_subscription_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_subscriptions TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_subscriptions TO authenticated;
GRANT EXECUTE ON FUNCTION process_subscription_renewal TO authenticated;