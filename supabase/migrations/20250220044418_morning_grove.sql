/*
  # Bulk Subscription Operations

  1. New Functions
    - `bulk_update_subscription_status`: Update status for multiple subscriptions
    - `bulk_convert_trials`: Convert multiple trials to paid subscriptions
    - `bulk_cancel_subscriptions`: Cancel multiple subscriptions
    - `get_bulk_operation_status`: Track bulk operation progress

  2. Changes
    - Added bulk operation tracking
    - Added batch processing
    - Added operation logging

  3. Security
    - Functions use SECURITY DEFINER
    - Input validation for all parameters
*/

-- Function to update multiple subscription statuses
CREATE OR REPLACE FUNCTION bulk_update_subscription_status(
  p_subscription_ids uuid[],
  p_status text,
  p_immediate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed integer := 0;
  v_failed integer := 0;
  v_operation_id uuid;
  v_subscription member_subscriptions;
  v_subscription_id uuid;
BEGIN
  -- Validate status
  IF p_status NOT IN ('active', 'canceled', 'past_due') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  -- Generate operation ID
  v_operation_id := gen_random_uuid();

  -- Process each subscription
  FOREACH v_subscription_id IN ARRAY p_subscription_ids
  LOOP
    BEGIN
      -- Get subscription details
      SELECT * INTO v_subscription
      FROM member_subscriptions
      WHERE id = v_subscription_id;

      -- Update subscription
      UPDATE member_subscriptions
      SET
        status = p_status,
        updated_at = now(),
        cancel_at_period_end = CASE 
          WHEN p_status = 'canceled' AND NOT p_immediate THEN true
          ELSE false
        END
      WHERE id = v_subscription_id;

      -- Log activity
      PERFORM log_user_activity(
        v_subscription.user_id,
        'bulk_status_update',
        jsonb_build_object(
          'operation_id', v_operation_id,
          'subscription_id', v_subscription_id,
          'old_status', v_subscription.status,
          'new_status', p_status,
          'immediate', p_immediate
        )
      );

      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'operation_id', v_operation_id,
    'total', array_length(p_subscription_ids, 1),
    'processed', v_processed,
    'failed', v_failed
  );
END;
$$;

-- Function to convert multiple trials to paid subscriptions
CREATE OR REPLACE FUNCTION bulk_convert_trials(
  p_subscription_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed integer := 0;
  v_failed integer := 0;
  v_operation_id uuid;
  v_subscription member_subscriptions;
  v_subscription_id uuid;
BEGIN
  -- Generate operation ID
  v_operation_id := gen_random_uuid();

  -- Process each subscription
  FOREACH v_subscription_id IN ARRAY p_subscription_ids
  LOOP
    BEGIN
      -- Get subscription details
      SELECT * INTO v_subscription
      FROM member_subscriptions
      WHERE id = v_subscription_id;

      -- Validate trial status
      IF NOT v_subscription.is_trial THEN
        RAISE EXCEPTION 'Subscription % is not in trial period', v_subscription_id;
      END IF;

      -- Convert to paid subscription
      UPDATE member_subscriptions
      SET
        is_trial = false,
        trial_ends_at = NULL,
        current_period_start = now(),
        current_period_end = now() + interval '1 month',
        updated_at = now()
      WHERE id = v_subscription_id;

      -- Log activity
      PERFORM log_user_activity(
        v_subscription.user_id,
        'bulk_trial_conversion',
        jsonb_build_object(
          'operation_id', v_operation_id,
          'subscription_id', v_subscription_id,
          'converted_at', now()
        )
      );

      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'operation_id', v_operation_id,
    'total', array_length(p_subscription_ids, 1),
    'processed', v_processed,
    'failed', v_failed
  );
END;
$$;

-- Function to cancel multiple subscriptions
CREATE OR REPLACE FUNCTION bulk_cancel_subscriptions(
  p_subscription_ids uuid[],
  p_immediate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed integer := 0;
  v_failed integer := 0;
  v_operation_id uuid;
  v_subscription member_subscriptions;
  v_subscription_id uuid;
BEGIN
  -- Generate operation ID
  v_operation_id := gen_random_uuid();

  -- Process each subscription
  FOREACH v_subscription_id IN ARRAY p_subscription_ids
  LOOP
    BEGIN
      -- Get subscription details
      SELECT * INTO v_subscription
      FROM member_subscriptions
      WHERE id = v_subscription_id;

      -- Update subscription
      UPDATE member_subscriptions
      SET
        status = CASE WHEN p_immediate THEN 'canceled' ELSE status END,
        cancel_at_period_end = true,
        updated_at = now()
      WHERE id = v_subscription_id;

      -- Log activity
      PERFORM log_user_activity(
        v_subscription.user_id,
        'bulk_cancellation',
        jsonb_build_object(
          'operation_id', v_operation_id,
          'subscription_id', v_subscription_id,
          'immediate', p_immediate,
          'effective_date', CASE 
            WHEN p_immediate THEN now()
            ELSE v_subscription.current_period_end
          END
        )
      );

      v_processed := v_processed + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'operation_id', v_operation_id,
    'total', array_length(p_subscription_ids, 1),
    'processed', v_processed,
    'failed', v_failed
  );
END;
$$;

-- Function to get bulk operation status
CREATE OR REPLACE FUNCTION get_bulk_operation_status(
  p_operation_id uuid
)
RETURNS TABLE (
  operation_type text,
  total_items integer,
  processed_items integer,
  failed_items integer,
  details jsonb[],
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH operation_data AS (
    SELECT
      action as op_type,
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE (details->>'error') IS NULL) as processed,
      COUNT(*) FILTER (WHERE (details->>'error') IS NOT NULL) as failed,
      ARRAY_AGG(details) as op_details,
      MIN(created_at) as op_created_at
    FROM user_activity
    WHERE 
      action LIKE 'bulk_%' AND
      (details->>'operation_id')::uuid = p_operation_id
    GROUP BY action
  )
  SELECT
    op_type,
    total::integer,
    processed::integer,
    failed::integer,
    op_details,
    op_created_at
  FROM operation_data;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION bulk_update_subscription_status TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_convert_trials TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_cancel_subscriptions TO authenticated;
GRANT EXECUTE ON FUNCTION get_bulk_operation_status TO authenticated;