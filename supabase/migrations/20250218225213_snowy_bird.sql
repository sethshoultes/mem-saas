/*
  # Remove RLS and enable unrestricted access
  
  1. Changes
    - Disable RLS on all tables
    - Grant full access to authenticated users
    - Keep helper functions but remove RLS checks
    - Simplify access patterns for development
*/

-- Disable RLS on all tables
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity DISABLE ROW LEVEL SECURITY;
ALTER TABLE membership_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE member_subscriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE content_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE content_access DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop policies for user_profiles
  DROP POLICY IF EXISTS "Users can view accessible profiles" ON user_profiles;
  DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
  DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;
  
  -- Drop policies for user_activity
  DROP POLICY IF EXISTS "View accessible user activity" ON user_activity;
  DROP POLICY IF EXISTS "Users can create their own activity" ON user_activity;
  DROP POLICY IF EXISTS "Admins can manage all activity" ON user_activity;
  
  -- Drop policies for other tables
  DROP POLICY IF EXISTS "Tenants can manage their own membership plans" ON membership_plans;
  DROP POLICY IF EXISTS "Users can view their own subscriptions" ON member_subscriptions;
  DROP POLICY IF EXISTS "Tenants can view their plan subscriptions" ON member_subscriptions;
  DROP POLICY IF EXISTS "Tenants can manage their own content" ON content_items;
  DROP POLICY IF EXISTS "Tenants can manage content access" ON content_access;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Recreate helper functions without RLS checks
CREATE OR REPLACE FUNCTION get_user_role(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role = 'admin' FROM user_profiles WHERE id = user_id;
$$;

CREATE OR REPLACE FUNCTION get_accessible_users(viewer_id uuid)
RETURNS SETOF user_profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT * FROM user_profiles;
$$;

CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT email FROM auth.users WHERE id = user_id;
$$;

-- Grant full access to authenticated users
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_email TO authenticated;