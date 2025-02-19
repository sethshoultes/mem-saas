/*
  # Complete Database Installation

  1. Tables
    - user_profiles: User information and settings
    - user_activity: User action logging
    - membership_plans: Subscription plan definitions
    - member_subscriptions: User subscriptions
    - content_items: Gated content storage
    - content_access: Content access rules

  2. Functions
    - User management helpers
    - Access control functions
    - Activity logging
    - Content access verification

  3. Security
    - Table permissions
    - Function permissions
    - Role-based access
*/

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

-- Create helper functions
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
  SELECT * FROM user_profiles;
$$;

CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT email FROM auth.users WHERE id = user_id;
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

CREATE OR REPLACE FUNCTION delete_user(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid;
  v_user_email text;
BEGIN
  -- Get the ID of the user making the request
  v_viewer_id := auth.uid();
  
  -- Check if the viewer is an admin
  IF NOT is_admin(v_viewer_id) THEN
    RAISE EXCEPTION 'Only administrators can delete users';
  END IF;

  -- Get the user's email for logging
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = target_user_id;

  -- Log the deletion activity
  PERFORM log_user_activity(
    target_user_id,
    'user_deleted',
    jsonb_build_object(
      'deleted_by', v_viewer_id,
      'deleted_at', now(),
      'email', v_user_email
    )
  );

  -- Soft delete by updating status and adding deletion info
  UPDATE user_profiles
  SET status = 'inactive',
      updated_at = now()
  WHERE id = target_user_id;

  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and re-raise
    PERFORM log_user_activity(
      target_user_id,
      'user_deletion_failed',
      jsonb_build_object(
        'error', SQLERRM,
        'attempted_by', v_viewer_id
      )
    );
    RAISE;
END;
$$;

-- Grant necessary permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION check_content_access TO authenticated;
GRANT EXECUTE ON FUNCTION log_user_activity TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;