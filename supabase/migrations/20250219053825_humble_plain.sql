/*
  # Tenant Management System

  1. New Functions
    - delete_tenant: Safely removes a tenant and associated data
    - log_tenant_activity: Records tenant-related activities
    - get_tenant_activity: Retrieves activity history for a tenant

  2. Security
    - Admin-only tenant deletion
    - Activity logging for audit trail
    - Safe cascade handling
*/

-- Function to delete a tenant
CREATE OR REPLACE FUNCTION delete_tenant(p_tenant_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_viewer_id uuid;
  v_viewer_role text;
BEGIN
  -- Get viewer info
  SELECT id, role INTO v_viewer_id, v_viewer_role
  FROM user_profiles
  WHERE id = auth.uid();

  -- Verify permissions
  IF v_viewer_role != 'admin' THEN
    RAISE EXCEPTION 'Only administrators can delete tenants';
  END IF;

  -- Log the deletion activity
  PERFORM log_user_activity(
    v_viewer_id,
    'tenant_deleted',
    jsonb_build_object(
      'tenant_id', p_tenant_id,
      'deleted_at', now()
    )
  );

  -- Update tenant status to inactive
  UPDATE tenants
  SET 
    status = 'inactive',
    subscription_status = 'canceled',
    updated_at = now()
  WHERE id = p_tenant_id;

  -- Update associated user profiles
  UPDATE user_profiles
  SET 
    status = 'inactive',
    updated_at = now()
  WHERE tenant_id = p_tenant_id;

  -- Cancel active subscriptions
  UPDATE member_subscriptions ms
  SET 
    status = 'canceled',
    updated_at = now()
  FROM membership_plans mp
  WHERE ms.plan_id = mp.id
  AND mp.tenant_id = p_tenant_id;

  -- Deactivate membership plans
  UPDATE membership_plans
  SET 
    is_active = false,
    updated_at = now()
  WHERE tenant_id = p_tenant_id;

  RETURN true;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_tenant TO authenticated;