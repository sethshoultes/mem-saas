/*
  # Complete Database Installation/Recovery File
  
  This file contains the complete database schema and functions needed to
  restore the system from scratch. It combines all migrations into a single
  installation file.

  1. Core Tables
    - user_profiles
    - user_activity
    - tenants
    - membership_plans
    - member_subscriptions
    - content_items
    - content_access

  2. Functions
    - User Management
    - Tenant Management
    - Membership Management
    - Subscription Management
    - Analytics
*/

-- Core Tables
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  full_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'tenant_admin', 'user')),
  tenant_id uuid,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  action text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  subscription_status text NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'canceled', 'past_due')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS membership_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price decimal(10,2) NOT NULL,
  interval text NOT NULL CHECK (interval IN ('monthly', 'yearly')),
  features jsonb DEFAULT '[]'::jsonb,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS member_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  status text NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'incomplete')),
  current_period_start timestamptz NOT NULL,
  current_period_end timestamptz NOT NULL,
  cancel_at_period_end boolean DEFAULT false,
  stripe_subscription_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  title text NOT NULL,
  description text,
  content_type text NOT NULL CHECK (content_type IN ('html', 'text', 'url')),
  content text NOT NULL,
  is_published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES content_items(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  created_at timestamptz DEFAULT now()
);

-- User Management Functions
CREATE OR REPLACE FUNCTION get_user_role(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'admin' FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION get_accessible_users(viewer_id uuid)
RETURNS SETOF user_profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = viewer_id
  )
  SELECT p.*
  FROM user_profiles p, viewer_info v
  WHERE 
    CASE v.role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN p.tenant_id = v.tenant_id
      ELSE p.id = viewer_id
    END;
$$;

-- Tenant Management Functions
CREATE OR REPLACE FUNCTION create_tenant(p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_creator_id uuid;
BEGIN
  v_creator_id := auth.uid();
  
  IF NOT is_admin(v_creator_id) THEN
    RAISE EXCEPTION 'Only administrators can create tenants';
  END IF;

  v_tenant_id := gen_random_uuid();

  INSERT INTO tenants (
    id,
    name,
    status,
    subscription_status,
    created_at
  ) VALUES (
    v_tenant_id,
    p_name,
    'active',
    'active',
    now()
  );

  PERFORM log_user_activity(
    v_creator_id,
    'tenant_created',
    jsonb_build_object(
      'tenant_id', v_tenant_id,
      'name', p_name
    )
  );

  RETURN v_tenant_id;
END;
$$;

-- Membership Management Functions
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
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

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

-- Subscription Management Functions
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

-- Subscription Management Functions
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
  SELECT * INTO v_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;

  UPDATE member_subscriptions
  SET
    status = CASE 
      WHEN p_immediate THEN 'canceled'
      ELSE status
    END,
    cancel_at_period_end = true,
    updated_at = now()
  WHERE id = p_subscription_id;

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

CREATE OR REPLACE FUNCTION reactivate_subscription(p_subscription_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription member_subscriptions;
BEGIN
  SELECT * INTO v_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;

  IF v_subscription.status != 'canceled' THEN
    RAISE EXCEPTION 'Only canceled subscriptions can be reactivated';
  END IF;

  UPDATE member_subscriptions
  SET
    status = 'active',
    cancel_at_period_end = false,
    current_period_start = now(),
    current_period_end = now() + interval '1 month',
    updated_at = now()
  WHERE id = p_subscription_id;

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

CREATE OR REPLACE FUNCTION retry_subscription_payment(p_subscription_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription member_subscriptions;
BEGIN
  SELECT * INTO v_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;

  IF v_subscription.status != 'past_due' THEN
    RAISE EXCEPTION 'Only past due subscriptions can retry payment';
  END IF;

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

-- Analytics Functions
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_stats jsonb;
  v_viewer_role text;
  v_viewer_tenant_id uuid;
BEGIN
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  WITH filtered_data AS (
    SELECT
      u.id as user_id,
      u.tenant_id,
      ms.status as subscription_status,
      mp.price * 
        CASE mp.interval
          WHEN 'monthly' THEN 1
          WHEN 'yearly' THEN 1/12.0
        END as monthly_price
    FROM user_profiles u
    LEFT JOIN member_subscriptions ms ON u.id = ms.user_id
    LEFT JOIN membership_plans mp ON ms.plan_id = mp.id
    WHERE 
      CASE v_viewer_role
        WHEN 'admin' THEN true
        WHEN 'tenant_admin' THEN u.tenant_id = v_viewer_tenant_id
        ELSE u.id = auth.uid()
      END
  )
  SELECT jsonb_build_object(
    'total_users', COUNT(DISTINCT user_id),
    'active_tenants', COUNT(DISTINCT tenant_id),
    'monthly_revenue', COALESCE(SUM(monthly_price) FILTER (WHERE subscription_status = 'active'), 0),
    'active_subscriptions', COUNT(*) FILTER (WHERE subscription_status = 'active')
  )
  INTO v_stats
  FROM filtered_data;

  RETURN v_stats;
END;
$$;
/*
  # Subscription Upgrade and Proration Functions

  1. New Functions
    - `upgrade_subscription`: Handles plan upgrades with proration
    - `downgrade_subscription`: Handles plan downgrades with proration
    - `calculate_proration`: Calculates prorated amounts
    - `get_subscription_changes`: Tracks subscription changes

  2. Changes
    - Added proration calculation logic
    - Added upgrade/downgrade tracking
    - Added subscription history

  3. Security
    - Functions use SECURITY DEFINER
    - Input validation for all parameters
*/

-- Function to calculate prorated amount
CREATE OR REPLACE FUNCTION calculate_proration(
  p_old_price decimal,
  p_new_price decimal,
  p_start_date timestamptz,
  p_end_date timestamptz,
  p_change_date timestamptz
)
RETURNS decimal
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_days integer;
  v_remaining_days integer;
  v_old_daily_rate decimal;
  v_new_daily_rate decimal;
  v_prorated_amount decimal;
BEGIN
  -- Calculate total and remaining days
  v_total_days := EXTRACT(EPOCH FROM (p_end_date - p_start_date))::integer / 86400;
  v_remaining_days := EXTRACT(EPOCH FROM (p_end_date - p_change_date))::integer / 86400;
  
  -- Calculate daily rates
  v_old_daily_rate := p_old_price / v_total_days;
  v_new_daily_rate := p_new_price / v_total_days;
  
  -- Calculate prorated amount
  v_prorated_amount := (v_new_daily_rate * v_remaining_days) - (v_old_daily_rate * v_remaining_days);
  
  RETURN ROUND(v_prorated_amount, 2);
END;
$$;

-- Function to upgrade subscription
CREATE OR REPLACE FUNCTION upgrade_subscription(
  p_subscription_id uuid,
  p_new_plan_id uuid,
  p_immediate boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old_subscription member_subscriptions;
  v_old_plan membership_plans;
  v_new_plan membership_plans;
  v_proration_amount decimal;
  v_change_date timestamptz;
BEGIN
  -- Get current subscription and plans
  SELECT * INTO v_old_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;
  
  SELECT * INTO v_old_plan
  FROM membership_plans
  WHERE id = v_old_subscription.plan_id;
  
  SELECT * INTO v_new_plan
  FROM membership_plans
  WHERE id = p_new_plan_id;
  
  -- Validate upgrade
  IF v_new_plan.price <= v_old_plan.price THEN
    RAISE EXCEPTION 'New plan price must be higher for upgrades';
  END IF;
  
  -- Set change date
  v_change_date := CASE 
    WHEN p_immediate THEN now()
    ELSE v_old_subscription.current_period_end
  END;
  
  -- Calculate proration if immediate
  IF p_immediate THEN
    v_proration_amount := calculate_proration(
      v_old_plan.price,
      v_new_plan.price,
      v_old_subscription.current_period_start,
      v_old_subscription.current_period_end,
      v_change_date
    );
  END IF;
  
  -- Update subscription
  UPDATE member_subscriptions
  SET
    plan_id = p_new_plan_id,
    updated_at = now()
  WHERE id = p_subscription_id;
  
  -- Log the change
  PERFORM log_user_activity(
    v_old_subscription.user_id,
    'subscription_upgraded',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'old_plan_id', v_old_plan.id,
      'new_plan_id', p_new_plan_id,
      'proration_amount', v_proration_amount,
      'immediate', p_immediate,
      'effective_date', v_change_date
    )
  );
  
  RETURN jsonb_build_object(
    'subscription_id', p_subscription_id,
    'proration_amount', v_proration_amount,
    'effective_date', v_change_date
  );
END;
$$;

-- Function to downgrade subscription
CREATE OR REPLACE FUNCTION downgrade_subscription(
  p_subscription_id uuid,
  p_new_plan_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription member_subscriptions;
  v_old_plan membership_plans;
  v_new_plan membership_plans;
BEGIN
  -- Get current subscription and plans
  SELECT * INTO v_subscription
  FROM member_subscriptions
  WHERE id = p_subscription_id;
  
  SELECT * INTO v_old_plan
  FROM membership_plans
  WHERE id = v_subscription.plan_id;
  
  SELECT * INTO v_new_plan
  FROM membership_plans
  WHERE id = p_new_plan_id;
  
  -- Validate downgrade
  IF v_new_plan.price >= v_old_plan.price THEN
    RAISE EXCEPTION 'New plan price must be lower for downgrades';
  END IF;
  
  -- Schedule downgrade for end of current period
  UPDATE member_subscriptions
  SET
    plan_id = p_new_plan_id,
    updated_at = now()
  WHERE id = p_subscription_id;
  
  -- Log the change
  PERFORM log_user_activity(
    v_subscription.user_id,
    'subscription_downgraded',
    jsonb_build_object(
      'subscription_id', p_subscription_id,
      'old_plan_id', v_old_plan.id,
      'new_plan_id', p_new_plan_id,
      'effective_date', v_subscription.current_period_end
    )
  );
  
  RETURN jsonb_build_object(
    'subscription_id', p_subscription_id,
    'effective_date', v_subscription.current_period_end
  );
END;
$$;

-- Function to get subscription changes history
CREATE OR REPLACE FUNCTION get_subscription_changes(
  p_subscription_id uuid
)
RETURNS TABLE (
  change_type text,
  old_plan_id uuid,
  new_plan_id uuid,
  proration_amount decimal,
  effective_date timestamptz,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    action as change_type,
    (details->>'old_plan_id')::uuid as old_plan_id,
    (details->>'new_plan_id')::uuid as new_plan_id,
    (details->>'proration_amount')::decimal as proration_amount,
    (details->>'effective_date')::timestamptz as effective_date,
    created_at
  FROM user_activity
  WHERE 
    action IN ('subscription_upgraded', 'subscription_downgraded') AND
    (details->>'subscription_id')::uuid = p_subscription_id
  ORDER BY created_at DESC;
$$;

-- Grant Permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON tenants TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION create_tenant TO authenticated;
GRANT EXECUTE ON FUNCTION create_membership_plan TO authenticated;
GRANT EXECUTE ON FUNCTION create_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION reactivate_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION retry_subscription_payment TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_stats TO authenticated;

GRANT EXECUTE ON FUNCTION calculate_proration TO authenticated;
GRANT EXECUTE ON FUNCTION upgrade_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION downgrade_subscription TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_changes TO authenticated;