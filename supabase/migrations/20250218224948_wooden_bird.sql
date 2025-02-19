/*
  # Enhanced user deletion function

  1. Changes
    - Added proper user deletion through auth.users
    - Added cascade deletion for related data
    - Improved error handling and validation

  2. Security
    - Maintains admin-only access
    - Logs deletion activity
    - Handles data cleanup safely
*/

-- Create an enhanced secure function to handle user deletion
CREATE OR REPLACE FUNCTION delete_user(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid;
  v_user_email text;
BEGIN
  -- Get the ID of the user making the request
  v_viewer_id := auth.uid();
  
  -- Check if the viewer is an admin
  IF NOT is_admin(v_viewer_id) THEN
    RAISE EXCEPTION 'Only administrators can delete users';
  END IF;

  -- Get the user's email for logging
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = target_user_id;

  -- Log the deletion activity
  PERFORM log_user_activity(
    target_user_id,
    'user_deleted',
    jsonb_build_object(
      'deleted_by', v_viewer_id,
      'deleted_at', now(),
      'email', v_user_email
    )
  );

  -- Delete user profile and related data
  DELETE FROM user_profiles WHERE id = target_user_id;
  
  -- Delete from auth.users using Supabase's built-in function
  -- This will cascade to all related data
  PERFORM auth.users.delete(target_user_id);

  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and re-raise
    PERFORM log_user_activity(
      target_user_id,
      'user_deletion_failed',
      jsonb_build_object(
        'error', SQLERRM,
        'deleted_by', v_viewer_id
      )
    );
    RAISE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;

-- Grant delete permission on auth.users to the postgres role
GRANT DELETE ON auth.users TO postgres;