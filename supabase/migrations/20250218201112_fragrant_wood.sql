/*
  # Fix user email access

  1. New Views
    - `auth_user_emails` - Secure view for accessing user emails
  
  2. Security
    - Enable RLS on the view
    - Add policies for secure email access
    - Grant necessary permissions
*/

-- Create a secure view for accessing user emails
CREATE OR REPLACE VIEW auth_user_emails AS
SELECT id, email, email_confirmed_at
FROM auth.users;

-- Enable RLS on the view
ALTER VIEW auth_user_emails ENABLE ROW LEVEL SECURITY;

-- Create policy for accessing emails
CREATE POLICY "Users can see emails of accessible users"
  ON auth_user_emails
  FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT id FROM get_accessible_users(auth.uid())
    )
  );

-- Grant access to the view
GRANT SELECT ON auth_user_emails TO authenticated;