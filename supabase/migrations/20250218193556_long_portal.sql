/*
  # Enable admin access functionality

  1. Changes
    - Add secure admin check functions
    - Create admin access policies
    - Enable service role access

  2. Security
    - Uses secure helper functions
    - Maintains RLS
    - Preserves data isolation
*/

-- Create secure helper functions
CREATE OR REPLACE FUNCTION is_service_or_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT 
    current_user = 'service_role' 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    );
$$;

-- Add admin access policies for user_profiles
CREATE POLICY "Service role and admins have full access to user_profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (is_service_or_admin());

-- Add admin access policies for user_activity
CREATE POLICY "Service role and admins have full access to user_activity"
  ON user_activity
  FOR ALL
  TO authenticated
  USING (is_service_or_admin());

-- Grant necessary permissions to authenticated users
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT EXECUTE ON FUNCTION is_service_or_admin TO authenticated;