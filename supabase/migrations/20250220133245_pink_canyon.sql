/*
  # Update membership plan functions to support trial periods

  1. Changes
    - Added trial_days parameter to create_membership_plan function
    - Added trial_days parameter to update_membership_plan function
    - Added trial period validation

  2. Security
    - Maintains existing security model
    - No changes to RLS policies
*/

-- Update create_membership_plan function to include trial_days
CREATE OR REPLACE FUNCTION create_membership_plan(
  p_name text,
  p_description text,
  p_price decimal,
  p_interval text,
  p_trial_days integer,
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
  -- Get tenant ID from current user
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Validate trial days
  IF p_trial_days < 0 THEN
    RAISE EXCEPTION 'Trial days cannot be negative';
  END IF;

  -- Create the plan
  INSERT INTO membership_plans (
    tenant_id,
    name,
    description,
    price,
    interval,
    trial_days,
    features
  )
  VALUES (
    v_tenant_id,
    p_name,
    p_description,
    p_price,
    p_interval,
    p_trial_days,
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
      'interval', p_interval,
      'trial_days', p_trial_days
    )
  );

  RETURN v_plan_id;
END;
$$;

-- Update update_membership_plan function to include trial_days
CREATE OR REPLACE FUNCTION update_membership_plan(
  p_plan_id uuid,
  p_name text,
  p_description text,
  p_price decimal,
  p_interval text,
  p_trial_days integer,
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
  -- Get tenant ID from current user
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Validate trial days
  IF p_trial_days < 0 THEN
    RAISE EXCEPTION 'Trial days cannot be negative';
  END IF;

  -- Update the plan
  UPDATE membership_plans
  SET
    name = COALESCE(p_name, name),
    description = p_description,
    price = COALESCE(p_price, price),
    interval = COALESCE(p_interval, interval),
    trial_days = COALESCE(p_trial_days, trial_days),
    features = COALESCE(p_features, features),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = now()
  WHERE id = p_plan_id AND tenant_id = v_tenant_id;

  -- Log activity
  PERFORM log_user_activity(
    auth.uid(),
    'plan_updated',
    jsonb_build_object(
      'plan_id', p_plan_id,
      'name', p_name,
      'price', p_price,
      'interval', p_interval,
      'trial_days', p_trial_days,
      'is_active', p_is_active
    )
  );

  RETURN FOUND;
END;
$$;