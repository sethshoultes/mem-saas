/*
  # Grant admin privileges to service role

  1. Changes
    - Grant admin privileges to service role for auth.users
    - Add service role policies for user_profiles
    - Add service role policies for user_activity

  2. Security
    - Maintains data isolation
    - Enables admin functionality
    - Preserves existing RLS
*/

-- Grant admin privileges to service role
ALTER USER service_role WITH CREATEROLE;

-- Add service role policies for user_profiles
CREATE POLICY "Service role has full access to user_profiles"
  ON user_profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Add service role policies for user_activity
CREATE POLICY "Service role has full access to user_activity"
  ON user_activity
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);