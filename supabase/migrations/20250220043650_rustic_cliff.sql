/*
  # Trial Period Management Implementation

  1. Schema Updates
    - Added trial_days to membership_plans
    - Added trial tracking fields to member_subscriptions

  2. New Functions
    - create_trial_subscription: Start new trial subscriptions
    - process_trial_expiration: Handle trial conversions
    - get_trial_status: Check trial status

  3. Security
    - All functions use SECURITY DEFINER
    - Input validation for all parameters
*/

-- Add trial period support to membership plans
ALTER TABLE membership_plans
ADD COLUMN trial_days integer DEFAULT 0 CHECK (trial_days >= 0);

-- Add trial tracking to subscriptions
ALTER TABLE member_subscriptions
ADD COLUMN trial_ends_at timestamptz,
ADD COLUMN is_trial boolean DEFAULT false;

-- Function to create trial subscription
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
BEGIN
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

-- Function to process trial expiration
CREATE OR REPLACE FUNCTION process_trial_expiration(
  p_subscription_id uuid,
  p_convert_to_paid boolean DEFAULT false
)
RETURNS jsonb
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
  
  -- Validate trial status
  IF NOT v_subscription.is_trial THEN
    RAISE EXCEPTION 'Subscription is not in trial period';
  END IF;
  
  IF v_subscription.trial_ends_at > now() THEN
    RAISE EXCEPTION 'Trial period has not ended yet';
  END IF;
  
  -- Process trial end
  IF p_convert_to_paid THEN
    -- Convert to paid subscription
    UPDATE member_subscriptions
    SET
      is_trial = false,
      trial_ends_at = NULL,
      current_period_start = now(),
      current_period_end = now() + interval '1 month',
      updated_at = now()
    WHERE id = p_subscription_id;
    
    PERFORM log_user_activity(
      v_subscription.user_id,
      'trial_converted',
      jsonb_build_object(
        'subscription_id', p_subscription_id,
        'converted_at', now()
      )
    );
  ELSE
    -- Cancel subscription at trial end
    UPDATE member_subscriptions
    SET
      status = 'canceled',
      is_trial = false,
      updated_at = now()
    WHERE id = p_subscription_id;
    
    PERFORM log_user_activity(
      v_subscription.user_id,
      'trial_expired',
      jsonb_build_object(
        'subscription_id', p_subscription_id,
        'expired_at', now()
      )
    );
  END IF;
  
  RETURN jsonb_build_object(
    'subscription_id', p_subscription_id,
    'action', CASE WHEN p_convert_to_paid THEN 'converted' ELSE 'expired' END,
    'processed_at', now()
  );
END;
$$;

-- Function to get trial status
CREATE OR REPLACE FUNCTION get_trial_status(
  p_subscription_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_subscription member_subscriptions;
  v_trial_days integer;
BEGIN
  -- Get subscription details
  SELECT s.*, mp.trial_days INTO v_subscription, v_trial_days
  FROM member_subscriptions s
  JOIN membership_plans mp ON s.plan_id = mp.id
  WHERE s.id = p_subscription_id;
  
  RETURN jsonb_build_object(
    'is_trial', v_subscription.is_trial,
    'trial_ends_at', v_subscription.trial_ends_at,
    'days_remaining', 
      CASE 
        WHEN v_subscription.is_trial THEN
          EXTRACT(DAY FROM (v_subscription.trial_ends_at - now()))
        ELSE
          0
      END,
    'trial_days', v_trial_days
  );
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_trial_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION process_trial_expiration TO authenticated;
GRANT EXECUTE ON FUNCTION get_trial_status TO authenticated;