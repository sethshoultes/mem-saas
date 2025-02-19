/*
  # Complete Database Installation

  1. Tables
    - user_profiles: User information and roles
    - user_activity: User action logging
    - membership_plans: Subscription plan definitions
    - member_subscriptions: User subscriptions
    - content_items: Gated content storage
    - content_access: Content access rules

  2. Functions
    - User Management Functions
    - Access Control Functions
    - Activity Logging
    - Content Access Verification
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

-- Function to get user role
CREATE OR REPLACE FUNCTION get_user_role(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = user_id;
$$;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'admin' FROM user_profiles WHERE id = user_id;
$$;

-- Function to get accessible users based on role
CREATE OR REPLACE FUNCTION get_accessible_users(viewer_id uuid)
RETURNS SETOF user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
  v_tenant_id uuid;
BEGIN
  -- Get the viewer's role and tenant
  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM user_profiles
  WHERE id = viewer_id;

  -- Return users based on role
  RETURN QUERY
  CASE v_role
    WHEN 'admin' THEN
      -- Admins can see all users
      SELECT * FROM user_profiles;
    WHEN 'tenant_admin' THEN
      -- Tenant admins can only see users in their tenant
      SELECT * FROM user_profiles
      WHERE tenant_id = v_tenant_id;
    ELSE
      -- Regular users can only see themselves
      SELECT * FROM user_profiles
      WHERE id = viewer_id;
  END CASE;
END;
$$;

-- Function to safely get user email with role-based access
CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_viewer_id uuid;
  v_viewer_role text;
  v_viewer_tenant uuid;
  v_target_tenant uuid;
  v_email text;
BEGIN
  -- Get the viewer's ID
  v_viewer_id := auth.uid();
  
  -- Get viewer's role and tenant
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant
  FROM user_profiles
  WHERE id = v_viewer_id;
  
  -- Get target user's tenant
  SELECT tenant_id INTO v_target_tenant
  FROM user_profiles
  WHERE id = user_id;
  
  -- Check access based on role
  IF v_viewer_role = 'admin' 
     OR (v_viewer_role = 'tenant_admin' AND v_viewer_tenant = v_target_tenant)
     OR v_viewer_id = user_id THEN
    -- Get the email if access is granted
    SELECT email INTO v_email
    FROM auth.users
    WHERE id = user_id;
    
    RETURN v_email;
  END IF;
  
  RETURN NULL; -- Return null if access is denied
END;
$$;

-- Function to check if a user can manage another user
CREATE OR REPLACE FUNCTION can_manage_user(manager_id uuid, target_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_manager_role text;
  v_manager_tenant uuid;
  v_target_tenant uuid;
BEGIN
  -- Get manager's role and tenant
  SELECT role, tenant_id INTO v_manager_role, v_manager_tenant
  FROM user_profiles
  WHERE id = manager_id;
  
  -- Get target's tenant
  SELECT tenant_id INTO v_target_tenant
  FROM user_profiles
  WHERE id = target_id;
  
  RETURN 
    CASE v_manager_role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN v_manager_tenant = v_target_tenant
      ELSE false
    END;
END;
$$;

-- Function to get users in a tenant
CREATE OR REPLACE FUNCTION get_tenant_users(tenant_id uuid)
RETURNS SETOF user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_viewer_id uuid;
  v_viewer_role text;
  v_viewer_tenant uuid;
BEGIN
  -- Get the viewer's ID
  v_viewer_id := auth.uid();
  
  -- Get viewer's role and tenant
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant
  FROM user_profiles
  WHERE id = v_viewer_id;
  
  -- Return users based on role and tenant access
  IF v_viewer_role = 'admin' 
     OR (v_viewer_role = 'tenant_admin' AND v_viewer_tenant = tenant_id) THEN
    RETURN QUERY
    SELECT * FROM user_profiles
    WHERE user_profiles.tenant_id = tenant_id;
  END IF;
  
  RETURN;
END;
$$;

-- Function to check content access
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

-- Function to log user activity
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

-- Function to delete user
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
GRANT EXECUTE ON FUNCTION can_manage_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_users TO authenticated;
GRANT EXECUTE ON FUNCTION check_content_access TO authenticated;
GRANT EXECUTE ON FUNCTION log_user_activity TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;