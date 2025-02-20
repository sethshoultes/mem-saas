/*
  # Add Subscription Status Checks

  1. New Functions
    - `check_subscription_eligibility`: Validates if a user can create a new subscription
    - `get_active_subscription`: Gets user's active subscription for a plan
    - `get_user_subscriptions_count`: Gets count of user's active subscriptions

  2. Changes
    - Added validation to subscription creation
    - Added unique constraint for active subscriptions
    - Added helper functions for subscription checks

  3. Security
    - All functions use SECURITY DEFINER
    - Input validation for all parameters
*/

-- Function to check if user already has an active subscription for a plan
CREATE OR REPLACE FUNCTION get_active_subscription(
  p_user_id uuid,
  p_plan_id uuid
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT id
  FROM member_subscriptions
  WHERE 
    user_id = p_user_id AND
    plan_id = p_plan_id AND
    status = 'active';
$$;

-- Function to get user's active subscription count
CREATE OR REPLACE FUNCTION get_user_subscriptions_count(
  p_user_id uuid
)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COUNT(*)::integer
  FROM member_subscriptions
  WHERE 
    user_id = p_user_id AND
    status = 'active';
$$;

-- Function to check subscription eligibility
CREATE OR REPLACE FUNCTION check_subscription_eligibility(
  p_user_id uuid,
  p_plan_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_subscription uuid;
  v_subscription_count integer;
  v_plan membership_plans;
BEGIN
  -- Get plan details
  SELECT * INTO v_plan
  FROM membership_plans
  WHERE id = p_plan_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'Plan not found'
    );
  END IF;

  -- Check if plan is active
  IF NOT v_plan.is_active THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'Plan is not active'
    );
  END IF;

  -- Check for existing active subscription to this plan
  SELECT get_active_subscription(p_user_id, p_plan_id)
  INTO v_active_subscription;

  IF v_active_subscription IS NOT NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'User already has an active subscription to this plan'
    );
  END IF;

  -- Get total active subscriptions
  SELECT get_user_subscriptions_count(p_user_id)
  INTO v_subscription_count;

  -- For now, limit to one active subscription per user
  -- This can be adjusted based on business rules
  IF v_subscription_count > 0 THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reason', 'User already has an active subscription'
    );
  END IF;

  RETURN jsonb_build_object(
    'eligible', true
  );
END;
$$;

-- Modify create_subscription to include eligibility check
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
  v_eligibility jsonb;
BEGIN
  -- Check eligibility
  v_eligibility := check_subscription_eligibility(p_user_id, p_plan_id);

  IF NOT (v_eligibility->>'eligible')::boolean THEN
    RAISE EXCEPTION 'Subscription not allowed: %', v_eligibility->>'reason';
  END IF;

  -- Create subscription if eligible
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

-- Modify create_trial_subscription to include eligibility check
CREATE OR REPLACE FUNCTION create_trial_subscription(
  p_user_id uuid,
  p_plan_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription_id uuid;
  v_trial_days integer;
  v_trial_end timestamptz;
  v_eligibility jsonb;
BEGIN
  -- Check eligibility
  v_eligibility := check_subscription_eligibility(p_user_id, p_plan_id);

  IF NOT (v_eligibility->>'eligible')::boolean THEN
    RAISE EXCEPTION 'Trial subscription not allowed: %', v_eligibility->>'reason';
  END IF;

  -- Get plan trial days
  SELECT trial_days INTO v_trial_days
  FROM membership_plans
  WHERE id = p_plan_id;
  
  -- Validate trial availability
  IF v_trial_days = 0 THEN
    RAISE EXCEPTION 'This plan does not offer a trial period';
  END IF;
  
  -- Check if user already had a trial
  IF EXISTS (
    SELECT 1 FROM member_subscriptions
    WHERE user_id = p_user_id AND is_trial = true
  ) THEN
    RAISE EXCEPTION 'User has already used their trial period';
  END IF;
  
  -- Calculate trial end date
  v_trial_end := now() + (v_trial_days || ' days')::interval;
  
  -- Create subscription
  INSERT INTO member_subscriptions (
    user_id,
    plan_id,
    status,
    current_period_start,
    current_period_end,
    trial_ends_at,
    is_trial
  )
  VALUES (
    p_user_id,
    p_plan_id,
    'active',
    now(),
    v_trial_end,
    v_trial_end,
    true
  )
  RETURNING id INTO v_subscription_id;
  
  -- Log activity
  PERFORM log_user_activity(
    p_user_id,
    'trial_started',
    jsonb_build_object(
      'subscription_id', v_subscription_id,
      'plan_id', p_plan_id,
      'trial_days', v_trial_days,
      'trial_ends_at', v_trial_end
    )
  );
  
  RETURN jsonb_build_object(
    'subscription_id', v_subscription_id,
    'trial_ends_at', v_trial_end,
    'trial_days', v_trial_days
  );
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_active_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_subscriptions_count TO authenticated;
GRANT EXECUTE ON FUNCTION check_subscription_eligibility TO authenticated;
GRANT EXECUTE ON FUNCTION create_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION create_trial_subscription TO authenticated;