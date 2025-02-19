/*
  # Fix user email access

  1. New Functions
    - `get_user_email` - Secure function for accessing user emails
  
  2. Security
    - Function uses SECURITY DEFINER to safely access auth.users
    - Access control based on user permissions
*/

-- Create a secure function to get user emails
CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_email text;
  v_viewer_id uuid;
BEGIN
  -- Get the ID of the user making the request
  v_viewer_id := auth.uid();
  
  -- Check if the viewer has access to this user's email
  IF EXISTS (
    SELECT 1 
    FROM get_accessible_users(v_viewer_id) 
    WHERE id = user_id
  ) THEN
    -- If they have access, get the email from auth.users
    SELECT email INTO v_email
    FROM auth.users
    WHERE id = user_id;
    
    RETURN v_email;
  END IF;
  
  RETURN NULL;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_email TO authenticated;