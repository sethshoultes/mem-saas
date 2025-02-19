/*
  # Enhanced User Management Functions

  1. New Functions
    - get_accessible_users: Returns users based on viewer's role and tenant
    - get_user_email: Securely retrieves user email with role-based access
    - can_manage_user: Checks if a user can manage another user
    - get_tenant_users: Returns users in a tenant with proper access control

  2. Security
    - All functions are SECURITY DEFINER
    - Role-based access control
    - Tenant isolation
*/

-- Function to get users accessible to the viewer based on their role
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

-- Function to safely get user email with role-based access
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

-- Function to check if a user can manage another user
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

-- Function to get users in a tenant
CREATE OR REPLACE FUNCTION get_tenant_users(tenant_id uuid)
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
  WHERE p.tenant_id = tenant_id
  AND (
    v.role = 'admin'
    OR (v.role = 'tenant_admin' AND v.tenant_id = tenant_id)
  );
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION can_manage_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_users TO authenticated;