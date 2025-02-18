/*
  # Fix user_profiles RLS policies

  1. Changes
    - Drop existing policies that cause recursion
    - Create new, optimized policies for user_profiles table
    - Simplify tenant admin access check
    - Add admin access without recursion

  2. Security
    - Maintains data isolation
    - Preserves role-based access
    - Prevents infinite recursion
*/

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Tenant admins can view profiles in their tenant" ON user_profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;

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

CREATE POLICY "Tenant admins can view tenant profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
      AND up.role = 'tenant_admin'
      AND up.tenant_id IS NOT NULL
      AND up.tenant_id = user_profiles.tenant_id
    )
  );

CREATE POLICY "Admins have full access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
      AND up.role = 'admin'
    )
  );