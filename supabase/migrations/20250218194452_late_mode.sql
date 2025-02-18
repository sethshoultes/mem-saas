/*
  # Secure User Management Implementation

  1. New Functions
    - Secure helper functions for role and access checks
    - Optimized query functions for user operations
  
  2. Security
    - Row Level Security policies for all tables
    - Role-based access control
    - Secure database functions
  
  3. Changes
    - Simplified policy structure
    - Optimized query performance
    - Enhanced security model
*/

-- Create secure helper functions
CREATE OR REPLACE FUNCTION get_user_role(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = user_id;
$$;

-- Function to check if a user is an admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'admin' FROM user_profiles WHERE id = user_id;
$$;

-- Function to check if a user is a tenant admin
CREATE OR REPLACE FUNCTION is_tenant_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'tenant_admin' FROM user_profiles WHERE id = user_id;
$$;

-- Function to get users for admin/tenant admin
CREATE OR REPLACE FUNCTION get_accessible_users(viewer_id uuid)
RETURNS SETOF user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Admin can see all users
  IF is_admin(viewer_id) THEN
    RETURN QUERY SELECT * FROM user_profiles;
  -- Tenant admin can see users in their tenant
  ELSIF is_tenant_admin(viewer_id) THEN
    RETURN QUERY 
      SELECT profiles.* 
      FROM user_profiles profiles
      WHERE profiles.tenant_id = (
        SELECT tenant_id 
        FROM user_profiles 
        WHERE id = viewer_id
      );
  -- Regular users can only see themselves
  ELSE
    RETURN QUERY 
      SELECT * 
      FROM user_profiles 
      WHERE id = viewer_id;
  END IF;
END;
$$;

-- Reset existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Tenant admins can view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins have full access" ON user_profiles;

-- Create new optimized policies for user_profiles
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

-- Reset existing policies for user_activity
DROP POLICY IF EXISTS "Users can view their own activity" ON user_activity;
DROP POLICY IF EXISTS "Tenant admins can view activity" ON user_activity;
DROP POLICY IF EXISTS "Admins can view all activity" ON user_activity;

-- Create new optimized policies for user_activity
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

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_tenant_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;