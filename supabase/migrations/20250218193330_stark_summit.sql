/*
  # Fix user_activity RLS policies

  1. Changes
    - Drop existing recursive policies
    - Create new, optimized policies for user_activity table
    - Simplify access checks
    - Add direct role-based policies

  2. Security
    - Maintains data isolation
    - Preserves role-based access
    - Prevents infinite recursion
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own activity" ON user_activity;
DROP POLICY IF EXISTS "Tenant admins can view activity in their tenant" ON user_activity;
DROP POLICY IF EXISTS "Admins can view all activity" ON user_activity;

-- Create new, optimized policies
CREATE POLICY "Users can view their own activity"
  ON user_activity
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Create a secure function to check admin status
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = user_id
    AND role = 'admin'
  );
$$;

-- Create a secure function to check tenant admin status and match
CREATE OR REPLACE FUNCTION is_tenant_admin_for_user(admin_id uuid, target_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles admin
    JOIN user_profiles target ON admin.tenant_id = target.tenant_id
    WHERE admin.id = admin_id
    AND admin.role = 'tenant_admin'
    AND target.id = target_user_id
  );
$$;

-- Admin policy using the secure function
CREATE POLICY "Admins can view all activity"
  ON user_activity
  FOR ALL
  TO authenticated
  USING (is_admin(auth.uid()));

-- Tenant admin policy using the secure function
CREATE POLICY "Tenant admins can view their users activity"
  ON user_activity
  FOR SELECT
  TO authenticated
  USING (is_tenant_admin_for_user(auth.uid(), user_id));