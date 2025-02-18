/*
  # Fix duplicate admin function and simplify RLS policies

  1. Changes
    - Renamed admin check function to avoid conflicts
    - Simplified RLS policies
    - Maintained basic data isolation
    - Added direct role-based access

  2. Security
    - Basic data isolation maintained
    - Simple role-based access
    - No recursive checks
*/

-- Drop existing complex policies
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Tenant admins can view tenant profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins have full access" ON user_profiles;
DROP POLICY IF EXISTS "Service role and admins have full access to user_profiles" ON user_profiles;

-- Simple admin check function with unique name
CREATE OR REPLACE FUNCTION check_admin_access()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'admin' FROM user_profiles WHERE id = auth.uid();
$$;

-- Simple policies for user_profiles
CREATE POLICY "Admins have full access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (check_admin_access());

CREATE POLICY "Users can view and update own profile"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = id);

-- Simple policies for user_activity
DROP POLICY IF EXISTS "Users can view their own activity" ON user_activity;
DROP POLICY IF EXISTS "Tenant admins can view activity in their tenant" ON user_activity;
DROP POLICY IF EXISTS "Admins can view all activity" ON user_activity;
DROP POLICY IF EXISTS "Service role and admins have full access to user_activity" ON user_activity;

CREATE POLICY "Admins can view all activity"
  ON user_activity
  FOR ALL
  TO authenticated
  USING (check_admin_access());

CREATE POLICY "Users can view own activity"
  ON user_activity
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT EXECUTE ON FUNCTION check_admin_access TO authenticated;