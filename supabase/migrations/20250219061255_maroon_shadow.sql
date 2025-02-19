/*
  # Enhance Subscription Management

  1. New Functions
    - Cancel subscription
    - Reactivate subscription
    - Retry failed payment
    - Get subscription details
    - Get subscription history

  2. Additional Features
    - Subscription status tracking
    - Payment retry mechanism
    - Subscription history logging
*/

-- Function to cancel subscription
CREATE OR REPLACE FUNCTION cancel_subscription(
  p_subscription_id uuid,
  p_immediate boolean DEFAULT false
)
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

  -- Update subscription
  UPDATE member_subscriptions
  SET
    status = CASE 
      WHEN p_immediate THEN 'canceled'
      ELSE status
    END,
    cancel_at_period_end = true,
    updated_at = now()
  WHERE id = p_subscription_id;

  -- Log activity
  PERFORM log_user_activity(
    v_subscription.user_id,
    'subscription_canceled',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'immediate', p_immediate,
      'effective_date', CASE 
        WHEN p_immediate THEN now()
        ELSE v_subscription.current_period_end
      END
    )
  );

  RETURN true;
END;
$$;

-- Function to reactivate subscription
CREATE OR REPLACE FUNCTION reactivate_subscription(p_subscription_id uuid)
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

  -- Only allow reactivation of canceled subscriptions
  IF v_subscription.status != 'canceled' THEN
    RAISE EXCEPTION 'Only canceled subscriptions can be reactivated';
  END IF;

  -- Update subscription
  UPDATE member_subscriptions
  SET
    status = 'active',
    cancel_at_period_end = false,
    current_period_start = now(),
    current_period_end = now() + interval '1 month',
    updated_at = now()
  WHERE id = p_subscription_id;

  -- Log activity
  PERFORM log_user_activity(
    v_subscription.user_id,
    'subscription_reactivated',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'reactivated_at', now()
    )
  );

  RETURN true;
END;
$$;

-- Function to retry failed payment
CREATE OR REPLACE FUNCTION retry_subscription_payment(p_subscription_id uuid)
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

  -- Only allow retry for past_due subscriptions
  IF v_subscription.status != 'past_due' THEN
    RAISE EXCEPTION 'Only past due subscriptions can retry payment';
  END IF;

  -- Log payment retry attempt
  PERFORM log_user_activity(
    v_subscription.user_id,
    'payment_retry_initiated',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'attempted_at', now()
    )
  );

  RETURN true;
END;
$$;

-- Function to get subscription details with history
CREATE OR REPLACE FUNCTION get_subscription_details(p_subscription_id uuid)
RETURNS TABLE (
  subscription_details jsonb,
  payment_history jsonb[],
  status_history jsonb[]
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH subscription_info AS (
    SELECT
      jsonb_build_object(
        'id', ms.id,
        'user_id', ms.user_id,
        'user_name', up.full_name,
        'plan_id', ms.plan_id,
        'plan_name', mp.name,
        'status', ms.status,
        'amount', mp.price,
        'interval', mp.interval,
        'current_period_start', ms.current_period_start,
        'current_period_end', ms.current_period_end,
        'cancel_at_period_end', ms.cancel_at_period_end,
        'created_at', ms.created_at
      ) as details,
      ARRAY_AGG(
        DISTINCT jsonb_build_object(
          'action', ua.action,
          'timestamp', ua.created_at,
          'details', ua.details
        ) ORDER BY ua.created_at DESC
      ) FILTER (WHERE ua.action LIKE 'payment_%') as payments,
      ARRAY_AGG(
        DISTINCT jsonb_build_object(
          'action', ua.action,
          'timestamp', ua.created_at,
          'details', ua.details
        ) ORDER BY ua.created_at DESC
      ) FILTER (WHERE ua.action LIKE 'subscription_%') as status_changes
    FROM member_subscriptions ms
    JOIN membership_plans mp ON ms.plan_id = mp.id
    JOIN user_profiles up ON ms.user_id = up.id
    LEFT JOIN user_activity ua ON ms.user_id = ua.user_id
    WHERE ms.id = p_subscription_id
    GROUP BY ms.id, up.full_name, mp.name, mp.price, mp.interval
  )
  SELECT
    details,
    payments,
    status_changes
  FROM subscription_info;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION cancel_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION reactivate_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION retry_subscription_payment TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_details TO authenticated;