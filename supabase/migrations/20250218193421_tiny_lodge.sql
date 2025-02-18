/*
  # Fix user_profiles RLS policies

  1. Changes
    - Drop existing recursive policies
    - Create new, optimized policies for user_profiles table
    - Add secure helper functions
    - Implement direct role checks

  2. Security
    - Maintains data isolation
    - Preserves role-based access
    - Prevents infinite recursion
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Tenant admins can view tenant profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins have full access" ON user_profiles;

-- Create secure helper functions
CREATE OR REPLACE FUNCTION get_user_role(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION get_user_tenant(user_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT tenant_id FROM user_profiles WHERE id = user_id;
$$;

-- Create new, optimized policies
CREATE POLICY "Users can view their own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins have full access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Tenant admins can view and update tenant profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (
    get_user_role(auth.uid()) = 'tenant_admin'
    AND get_user_tenant(auth.uid()) = user_profiles.tenant_id
  );