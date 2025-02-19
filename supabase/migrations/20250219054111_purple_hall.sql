/*
  # Tenant Management System

  1. New Tables
    - tenants: Stores tenant organizations
      - id (uuid, primary key)
      - name (text)
      - status (text)
      - subscription_status (text)
      - created_at (timestamptz)
      - updated_at (timestamptz)

  2. New Functions
    - create_tenant: Creates new tenant organizations
    - update_tenant: Updates tenant details
    - delete_tenant: Safely removes tenants
    - get_accessible_tenants: Retrieves accessible tenants
    - get_tenant_stats: Calculates tenant statistics
*/

-- Create tenants table
CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  subscription_status text NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'canceled', 'past_due')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Function to create a new tenant
CREATE OR REPLACE FUNCTION create_tenant(p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_creator_id uuid;
BEGIN
  -- Get the ID of the user creating the tenant
  v_creator_id := auth.uid();
  
  -- Check if the user is an admin
  IF NOT is_admin(v_creator_id) THEN
    RAISE EXCEPTION 'Only administrators can create tenants';
  END IF;

  -- Generate new tenant ID
  v_tenant_id := gen_random_uuid();

  -- Create tenant profile
  INSERT INTO tenants (
    id,
    name,
    status,
    subscription_status,
    created_at
  ) VALUES (
    v_tenant_id,
    p_name,
    'active',
    'active',
    now()
  );

  -- Log activity
  PERFORM log_user_activity(
    v_creator_id,
    'tenant_created',
    jsonb_build_object(
      'tenant_id', v_tenant_id,
      'name', p_name
    )
  );

  RETURN v_tenant_id;
END;
$$;

-- Function to update tenant details
CREATE OR REPLACE FUNCTION update_tenant(
  p_tenant_id uuid,
  p_name text DEFAULT NULL,
  p_status text DEFAULT NULL
)
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
    RAISE EXCEPTION 'Only administrators can update tenants';
  END IF;

  -- Update tenant
  UPDATE tenants
  SET
    name = COALESCE(p_name, name),
    status = COALESCE(p_status, status),
    updated_at = now()
  WHERE id = p_tenant_id;

  -- Log activity
  PERFORM log_user_activity(
    v_viewer_id,
    'tenant_updated',
    jsonb_build_object(
      'tenant_id', p_tenant_id,
      'name', p_name,
      'status', p_status
    )
  );

  RETURN FOUND;
END;
$$;

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

-- Function to get accessible tenants
CREATE OR REPLACE FUNCTION get_accessible_tenants()
RETURNS SETOF tenants
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_viewer_role text;
  v_viewer_tenant_id uuid;
BEGIN
  -- Get viewer's role and tenant
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  RETURN QUERY
  SELECT t.*
  FROM tenants t
  WHERE 
    CASE v_viewer_role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN t.id = v_viewer_tenant_id
      ELSE false
    END
  ORDER BY t.created_at DESC;
END;
$$;

-- Function to get tenant statistics
CREATE OR REPLACE FUNCTION get_tenant_stats(p_tenant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_users', (
      SELECT COUNT(*)
      FROM user_profiles
      WHERE tenant_id = p_tenant_id
    ),
    'active_plans', (
      SELECT COUNT(*)
      FROM membership_plans
      WHERE tenant_id = p_tenant_id
      AND is_active = true
    ),
    'total_revenue', (
      SELECT COALESCE(SUM(mp.price), 0)
      FROM member_subscriptions ms
      JOIN membership_plans mp ON ms.plan_id = mp.id
      WHERE mp.tenant_id = p_tenant_id
      AND ms.status = 'active'
    )
  ) INTO v_stats;

  RETURN v_stats;
END;
$$;

-- Grant necessary permissions
GRANT ALL ON tenants TO authenticated;
GRANT EXECUTE ON FUNCTION create_tenant TO authenticated;
GRANT EXECUTE ON FUNCTION update_tenant TO authenticated;
GRANT EXECUTE ON FUNCTION delete_tenant TO authenticated;
GRANT EXECUTE ON FUNCTION get_accessible_tenants TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_stats TO authenticated;