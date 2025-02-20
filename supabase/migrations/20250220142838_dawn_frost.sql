/*
  # Complete Database Recovery Migration

  This migration provides a complete installation/recovery of the database schema,
  including all tables, functions, and security settings.

  1. Core Tables
    - User profiles and activity tracking
    - Tenant management
    - Membership plans and subscriptions
    - Content management
    - Mock payment system

  2. Functions
    - User management
    - Tenant operations
    - Subscription handling
    - Payment processing
    - Analytics and reporting

  3. Security
    - Function permissions
    - Table access
    - Data validation
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
  trial_days integer DEFAULT 0 CHECK (trial_days >= 0),
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
  trial_ends_at timestamptz,
  is_trial boolean DEFAULT false,
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

-- Mock Payment System Tables
CREATE TABLE IF NOT EXISTS mock_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  amount decimal NOT NULL,
  currency text DEFAULT 'usd',
  status text CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method_id text,
  error_code text,
  error_message text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mock_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  type text DEFAULT 'card',
  card_number text,
  exp_month integer,
  exp_year integer,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mock_webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  event_type text NOT NULL,
  data jsonb NOT NULL,
  processed boolean DEFAULT false,
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
  SELECT tenant_id INTO v_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Validate trial days
  IF p_trial_days < 0 THEN
    RAISE EXCEPTION 'Trial days cannot be negative';
  END IF;

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

-- Subscription Management Functions
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

-- Mock Payment Processing
CREATE OR REPLACE FUNCTION process_mock_payment(
  p_tenant_id uuid,
  p_amount decimal,
  p_currency text DEFAULT 'usd',
  p_card_number text DEFAULT '4242424242424242',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_transaction_id uuid;
  v_status text;
  v_error_code text;
  v_error_message text;
BEGIN
  -- Simulate payment processing based on test card numbers
  CASE p_card_number
    WHEN '4242424242424242' THEN
      v_status := 'completed';
    WHEN '4000000000000002' THEN
      v_status := 'failed';
      v_error_code := 'card_declined';
      v_error_message := 'Your card was declined';
    WHEN '4000000000009995' THEN
      v_status := 'failed';
      v_error_code := 'insufficient_funds';
      v_error_message := 'Insufficient funds';
    ELSE
      v_status := 'failed';
      v_error_code := 'invalid_card';
      v_error_message := 'Invalid card number';
  END CASE;

  -- Create transaction record
  INSERT INTO mock_transactions (
    tenant_id,
    amount,
    currency,
    status,
    payment_method_id,
    error_code,
    error_message,
    metadata
  ) VALUES (
    p_tenant_id,
    p_amount,
    p_currency,
    v_status,
    p_card_number,
    v_error_code,
    v_error_message,
    p_metadata
  )
  RETURNING id INTO v_transaction_id;

  -- Create webhook event
  INSERT INTO mock_webhooks (
    tenant_id,
    event_type,
    data
  ) VALUES (
    p_tenant_id,
    CASE v_status
      WHEN 'completed' THEN 'payment_intent.succeeded'
      ELSE 'payment_intent.failed'
    END,
    jsonb_build_object(
      'transaction_id', v_transaction_id,
      'amount', p_amount,
      'currency', p_currency,
      'status', v_status,
      'error', CASE 
        WHEN v_error_code IS NOT NULL THEN
          jsonb_build_object(
            'code', v_error_code,
            'message', v_error_message
          )
        ELSE NULL
      END
    )
  );

  RETURN jsonb_build_object(
    'id', v_transaction_id,
    'status', v_status,
    'error', CASE 
      WHEN v_error_code IS NOT NULL THEN
        jsonb_build_object(
          'code', v_error_code,
          'message', v_error_message
        )
      ELSE NULL
    END
  );
END;
$$;

-- Grant necessary permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON tenants TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;
GRANT ALL ON mock_transactions TO authenticated;
GRANT ALL ON mock_payment_methods TO authenticated;
GRANT ALL ON mock_webhooks TO authenticated;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;