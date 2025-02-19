/*
  # Fix user deletion function

  1. Changes
    - Remove direct auth.users deletion
    - Implement soft deletion pattern
    - Add status tracking
    - Improve error handling

  2. Security
    - Function runs with SECURITY DEFINER
    - Only accessible to authenticated users
    - Checks admin permissions
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

  -- Soft delete by updating status and adding deletion info
  UPDATE user_profiles
  SET status = 'inactive',
      updated_at = now()
  WHERE id = target_user_id;

  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and re-raise
    PERFORM log_user_activity(
      target_user_id,
      'user_deletion_failed',
      jsonb_build_object(
        'error', SQLERRM,
        'attempted_by', v_viewer_id
      )
    );
    RAISE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;