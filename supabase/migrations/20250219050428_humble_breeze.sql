/*
  # Complete Database Installation

  1. Tables
    - user_profiles: User profile information and roles
    - user_activity: User activity logging
    - membership_plans: Subscription plan definitions
    - member_subscriptions: User subscriptions
    - content_items: Gated content
    - content_access: Content access rules

  2. Functions
    - User Management: Role checks, access control
    - Activity Logging: Audit trail
    - Content Access: Subscription validation
    - Search & Filtering: Advanced queries
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

-- Basic User Functions
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

-- User Access Functions
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

CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = auth.uid()
  ),
  target_info AS (
    SELECT tenant_id
    FROM user_profiles
    WHERE id = user_id
  )
  SELECT email
  FROM auth.users
  WHERE id = user_id
  AND EXISTS (
    SELECT 1
    FROM viewer_info v, target_info t
    WHERE v.role = 'admin'
    OR (v.role = 'tenant_admin' AND v.tenant_id = t.tenant_id)
    OR auth.uid() = user_id
  );
$$;

-- User Management Functions
CREATE OR REPLACE FUNCTION can_manage_user(manager_id uuid, target_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH manager_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = manager_id
  ),
  target_info AS (
    SELECT tenant_id
    FROM user_profiles
    WHERE id = target_id
  )
  SELECT EXISTS (
    SELECT 1
    FROM manager_info m, target_info t
    WHERE 
      CASE m.role
        WHEN 'admin' THEN true
        WHEN 'tenant_admin' THEN m.tenant_id = t.tenant_id
        ELSE false
      END
  );
$$;

CREATE OR REPLACE FUNCTION get_tenant_users(p_tenant_id uuid)
RETURNS SETOF user_profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = auth.uid()
  )
  SELECT p.*
  FROM user_profiles p, viewer_info v
  WHERE p.tenant_id = p_tenant_id
  AND (
    v.role = 'admin'
    OR (v.role = 'tenant_admin' AND v.tenant_id = p_tenant_id)
  );
$$;

-- Activity and Audit Functions
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

CREATE OR REPLACE FUNCTION get_user_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT jsonb_build_object(
    'total_logins', COUNT(*) FILTER (WHERE action = 'user_login'),
    'last_login', MAX(created_at) FILTER (WHERE action = 'user_login'),
    'status_changes', COUNT(*) FILTER (WHERE action = 'profile_updated' AND details ? 'status'),
    'role_changes', COUNT(*) FILTER (WHERE action = 'profile_updated' AND details ? 'role'),
    'password_resets', COUNT(*) FILTER (WHERE action = 'password_reset_requested')
  )
  FROM user_activity
  WHERE user_id = p_user_id;
$$;

-- User Search and Update Functions
CREATE OR REPLACE FUNCTION search_users(
  p_query text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_tenant_id uuid DEFAULT NULL,
  p_created_after timestamptz DEFAULT NULL,
  p_created_before timestamptz DEFAULT NULL
)
RETURNS SETOF user_profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = auth.uid()
  )
  SELECT DISTINCT p.*
  FROM user_profiles p
  CROSS JOIN viewer_info v
  WHERE (
    -- Role-based access check
    CASE v.role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN p.tenant_id = v.tenant_id
      ELSE p.id = auth.uid()
    END
  )
  AND (
    -- Search query
    p_query IS NULL
    OR p.full_name ILIKE '%' || p_query || '%'
    OR EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = p.id
      AND u.email ILIKE '%' || p_query || '%'
    )
  )
  AND (p_role IS NULL OR p.role = p_role)
  AND (p_status IS NULL OR p.status = p_status)
  AND (p_tenant_id IS NULL OR p.tenant_id = p_tenant_id)
  AND (p_created_after IS NULL OR p.created_at >= p_created_after)
  AND (p_created_before IS NULL OR p.created_at <= p_created_before)
  ORDER BY p.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION bulk_update_users(
  p_user_ids uuid[],
  p_status text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_tenant_id uuid DEFAULT NULL
)
RETURNS TABLE (updated_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_viewer_id uuid;
  v_viewer_role text;
  v_viewer_tenant uuid;
  v_user_id uuid;
BEGIN
  -- Get viewer info
  SELECT id, role, tenant_id INTO v_viewer_id, v_viewer_role, v_viewer_tenant
  FROM user_profiles
  WHERE id = auth.uid();

  -- Verify viewer permissions
  IF v_viewer_role NOT IN ('admin', 'tenant_admin') THEN
    RAISE EXCEPTION 'Insufficient permissions for bulk updates';
  END IF;

  -- Process each user
  FOR v_user_id IN SELECT unnest(p_user_ids)
  LOOP
    -- Check if viewer can manage this user
    IF EXISTS (
      SELECT 1 FROM user_profiles target
      WHERE target.id = v_user_id
      AND (
        v_viewer_role = 'admin'
        OR (v_viewer_role = 'tenant_admin' AND target.tenant_id = v_viewer_tenant)
      )
    ) THEN
      -- Update user profile
      UPDATE user_profiles
      SET
        status = COALESCE(p_status, status),
        role = COALESCE(p_role, role),
        tenant_id = COALESCE(p_tenant_id, tenant_id),
        updated_at = now()
      WHERE id = v_user_id
      RETURNING id INTO updated_id;

      -- Log the activity
      PERFORM log_user_activity(
        v_user_id,
        'bulk_update',
        jsonb_build_object(
          'updated_by', v_viewer_id,
          'status', p_status,
          'role', p_role,
          'tenant_id', p_tenant_id
        )
      );

      RETURN NEXT;
    END IF;
  END LOOP;

  RETURN;
END;
$$;

-- Content Access Functions
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

-- User Deletion Function
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
GRANT EXECUTE ON FUNCTION get_user_stats TO authenticated;
GRANT EXECUTE ON FUNCTION search_users TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_update_users TO authenticated;