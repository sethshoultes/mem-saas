/*
  # Add Role-Based Access Control Functions

  1. New Functions
    - `get_accessible_users`: Returns users based on viewer's role
    - `get_user_email`: Returns user email with role-based access
    - `can_manage_user`: Checks if a user can manage another user
    - `get_tenant_users`: Returns users in a tenant

  2. Security
    - Role-based filtering for user access
    - Tenant isolation for tenant admins
    - Email access control
    - User management permissions
*/

-- Function to get users accessible to the viewer based on their role
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

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION can_manage_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_users TO authenticated;