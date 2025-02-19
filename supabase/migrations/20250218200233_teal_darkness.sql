/*
  # Database Recovery and Setup

  1. Tables
    - user_profiles: User information and roles
    - user_activity: User action logging
    - membership_plans: Subscription plan details
    - member_subscriptions: User subscriptions
    - content_items: Gated content
    - content_access: Content access rules

  2. Functions
    - Role and access management
    - Content access verification
    - Activity logging

  3. Security
    - Row Level Security (RLS)
    - Role-based access control
    - Secure helper functions
*/

-- Drop existing policies to prevent conflicts
DO $$ 
BEGIN
  -- Drop policies for user_profiles
  DROP POLICY IF EXISTS "Users can view accessible profiles" ON user_profiles;
  DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
  DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;
  
  -- Drop policies for user_activity
  DROP POLICY IF EXISTS "View accessible user activity" ON user_activity;
  DROP POLICY IF EXISTS "Users can create their own activity" ON user_activity;
  DROP POLICY IF EXISTS "Admins can manage all activity" ON user_activity;
  
  -- Drop policies for other tables
  DROP POLICY IF EXISTS "Tenants can manage their own membership plans" ON membership_plans;
  DROP POLICY IF EXISTS "Users can view their own subscriptions" ON member_subscriptions;
  DROP POLICY IF EXISTS "Tenants can view their plan subscriptions" ON member_subscriptions;
  DROP POLICY IF EXISTS "Tenants can manage their own content" ON content_items;
  DROP POLICY IF EXISTS "Tenants can manage content access" ON content_access;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Create tables with safe CREATE IF NOT EXISTS
DO $$ 
BEGIN
  -- User Profiles Table
  CREATE TABLE IF NOT EXISTS user_profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id),
    full_name text NOT NULL,
    role text NOT NULL CHECK (role IN ('admin', 'tenant_admin', 'user')),
    tenant_id uuid,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );

  -- User Activity Table
  CREATE TABLE IF NOT EXISTS user_activity (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id),
    action text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
  );

  -- Membership Plans Table
  CREATE TABLE IF NOT EXISTS membership_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES auth.users(id),
    name text NOT NULL,
    description text,
    price decimal(10,2) NOT NULL,
    interval text NOT NULL CHECK (interval IN ('monthly', 'yearly')),
    features jsonb DEFAULT '[]'::jsonb,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );

  -- Member Subscriptions Table
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

  -- Content Items Table
  CREATE TABLE IF NOT EXISTS content_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES auth.users(id),
    title text NOT NULL,
    description text,
    content_type text NOT NULL CHECK (content_type IN ('html', 'text', 'url')),
    content text NOT NULL,
    is_published boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );

  -- Content Access Table
  CREATE TABLE IF NOT EXISTS content_access (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id uuid NOT NULL REFERENCES content_items(id),
    plan_id uuid NOT NULL REFERENCES membership_plans(id),
    created_at timestamptz DEFAULT now()
  );
END $$;

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_access ENABLE ROW LEVEL SECURITY;

-- Create or replace helper functions
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

CREATE OR REPLACE FUNCTION is_tenant_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'tenant_admin' FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION get_accessible_users(viewer_id uuid)
RETURNS SETOF user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  IF is_admin(viewer_id) THEN
    RETURN QUERY SELECT * FROM user_profiles;
  ELSIF is_tenant_admin(viewer_id) THEN
    RETURN QUERY 
      SELECT profiles.* 
      FROM user_profiles profiles
      WHERE profiles.tenant_id = (
        SELECT tenant_id 
        FROM user_profiles 
        WHERE id = viewer_id
      );
  ELSE
    RETURN QUERY 
      SELECT * 
      FROM user_profiles 
      WHERE id = viewer_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION check_content_access(p_content_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM content_access ca
    JOIN member_subscriptions ms ON ca.plan_id = ms.plan_id
    WHERE ca.content_id = p_content_id
    AND ms.user_id = p_user_id
    AND ms.status = 'active'
    AND ms.current_period_end > now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_user_activity(
  p_user_id uuid,
  p_action text,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_activity_id uuid;
BEGIN
  INSERT INTO user_activity (user_id, action, details)
  VALUES (p_user_id, p_action, p_details)
  RETURNING id INTO v_activity_id;
  
  RETURN v_activity_id;
END;
$$;

-- Create new policies
CREATE POLICY "Users can view accessible profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT id FROM get_accessible_users(auth.uid())
    )
  );

CREATE POLICY "Users can update their own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "View accessible user activity"
  ON user_activity
  FOR SELECT
  TO authenticated
  USING (
    user_id IN (
      SELECT id FROM get_accessible_users(auth.uid())
    )
  );

CREATE POLICY "Users can create their own activity"
  ON user_activity
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all activity"
  ON user_activity
  FOR ALL
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Tenants can manage their own membership plans"
  ON membership_plans
  FOR ALL
  TO authenticated
  USING (auth.uid() = tenant_id);

CREATE POLICY "Users can view their own subscriptions"
  ON member_subscriptions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Tenants can view their plan subscriptions"
  ON member_subscriptions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM membership_plans
      WHERE membership_plans.id = member_subscriptions.plan_id
      AND membership_plans.tenant_id = auth.uid()
    )
  );

CREATE POLICY "Tenants can manage their own content"
  ON content_items
  FOR ALL
  TO authenticated
  USING (auth.uid() = tenant_id);

CREATE POLICY "Tenants can manage content access"
  ON content_access
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM content_items
      WHERE content_items.id = content_access.content_id
      AND content_items.tenant_id = auth.uid()
    )
  );

-- Grant necessary permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_tenant_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION check_content_access TO authenticated;
GRANT EXECUTE ON FUNCTION log_user_activity TO authenticated;