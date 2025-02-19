/*
  # Add secure user deletion function

  1. New Functions
    - `delete_user`: Secure function to handle user deletion
      - Deletes user profile
      - Logs deletion activity
      - Marks user as inactive

  2. Security
    - Function runs with SECURITY DEFINER
    - Only accessible to authenticated users
    - Checks admin permissions
*/

-- Create a secure function to handle user deletion
CREATE OR REPLACE FUNCTION delete_user(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid;
BEGIN
  -- Get the ID of the user making the request
  v_viewer_id := auth.uid();
  
  -- Check if the viewer is an admin
  IF NOT is_admin(v_viewer_id) THEN
    RAISE EXCEPTION 'Only administrators can delete users';
  END IF;

  -- Log the deletion activity
  PERFORM log_user_activity(
    target_user_id,
    'user_deleted',
    jsonb_build_object('deleted_by', v_viewer_id, 'deleted_at', now())
  );

  -- Update user profile to inactive status
  UPDATE user_profiles
  SET status = 'inactive',
      updated_at = now()
  WHERE id = target_user_id;

  RETURN true;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;