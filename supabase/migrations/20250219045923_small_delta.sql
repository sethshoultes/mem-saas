/*
  # Enhanced User Management Features

  1. New Functions
    - get_user_stats: Returns user activity statistics
    - search_users: Advanced user search with filtering
    - bulk_update_users: Batch update user statuses
    - get_user_audit_log: Detailed audit trail for user actions

  2. Security
    - All functions are SECURITY DEFINER
    - Role-based access control
    - Audit logging for all operations
*/

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_logins', COUNT(*) FILTER (WHERE action = 'user_login'),
    'last_login', MAX(created_at) FILTER (WHERE action = 'user_login'),
    'status_changes', COUNT(*) FILTER (WHERE action = 'profile_updated' AND details ? 'status'),
    'role_changes', COUNT(*) FILTER (WHERE action = 'profile_updated' AND details ? 'role'),
    'password_resets', COUNT(*) FILTER (WHERE action = 'password_reset_requested')
  )
  INTO v_stats
  FROM user_activity
  WHERE user_id = p_user_id;

  RETURN v_stats;
END;
$$;

-- Function for advanced user search
CREATE OR REPLACE FUNCTION search_users(
  p_query text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_tenant_id uuid DEFAULT NULL,
  p_created_after timestamptz DEFAULT NULL,
  p_created_before timestamptz DEFAULT NULL
)
RETURNS SETOF user_profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = auth.uid()
  )
  SELECT DISTINCT p.*
  FROM user_profiles p
  CROSS JOIN viewer_info v
  WHERE (
    -- Role-based access check
    CASE v.role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN p.tenant_id = v.tenant_id
      ELSE p.id = auth.uid()
    END
  )
  AND (
    -- Search query
    p_query IS NULL
    OR p.full_name ILIKE '%' || p_query || '%'
    OR EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = p.id
      AND u.email ILIKE '%' || p_query || '%'
    )
  )
  AND (p_role IS NULL OR p.role = p_role)
  AND (p_status IS NULL OR p.status = p_status)
  AND (p_tenant_id IS NULL OR p.tenant_id = p_tenant_id)
  AND (p_created_after IS NULL OR p.created_at >= p_created_after)
  AND (p_created_before IS NULL OR p.created_at <= p_created_before)
  ORDER BY p.created_at DESC;
$$;

-- Function for bulk user updates
CREATE OR REPLACE FUNCTION bulk_update_users(
  p_user_ids uuid[],
  p_status text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_tenant_id uuid DEFAULT NULL
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_viewer_id uuid;
  v_viewer_role text;
  v_viewer_tenant uuid;
  v_user_id uuid;
BEGIN
  -- Get viewer info
  SELECT id, role, tenant_id INTO v_viewer_id, v_viewer_role, v_viewer_tenant
  FROM user_profiles
  WHERE id = auth.uid();

  -- Verify viewer permissions
  IF v_viewer_role NOT IN ('admin', 'tenant_admin') THEN
    RAISE EXCEPTION 'Insufficient permissions for bulk updates';
  END IF;

  -- Process each user
  FOREACH v_user_id IN ARRAY p_user_ids
  LOOP
    -- Check if viewer can manage this user
    IF can_manage_user(v_viewer_id, v_user_id) THEN
      -- Prepare update data
      WITH update_data AS (
        UPDATE user_profiles
        SET
          status = COALESCE(p_status, status),
          role = COALESCE(p_role, role),
          tenant_id = COALESCE(p_tenant_id, tenant_id),
          updated_at = now()
        WHERE id = v_user_id
        RETURNING id
      )
      -- Log the activity
      SELECT log_user_activity(
        v_user_id,
        'bulk_update',
        jsonb_build_object(
          'updated_by', v_viewer_id,
          'status', p_status,
          'role', p_role,
          'tenant_id', p_tenant_id
        )
      );

      RETURN NEXT v_user_id;
    END IF;
  END LOOP;

  RETURN;
END;
$$;

-- Function to get detailed user audit log
CREATE OR REPLACE FUNCTION get_user_audit_log(
  p_user_id uuid,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL,
  p_actions text[] DEFAULT NULL
)
RETURNS TABLE (
  activity_id uuid,
  action text,
  details jsonb,
  created_at timestamptz,
  actor_id uuid,
  actor_name text,
  actor_role text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  WITH viewer_info AS (
    SELECT role, tenant_id
    FROM user_profiles
    WHERE id = auth.uid()
  ),
  target_info AS (
    SELECT tenant_id
    FROM user_profiles
    WHERE id = p_user_id
  )
  SELECT 
    a.id,
    a.action,
    a.details,
    a.created_at,
    COALESCE(a.details->>'updated_by', a.details->>'deleted_by', a.user_id) as actor_id,
    actor.full_name,
    actor.role
  FROM user_activity a
  CROSS JOIN viewer_info v
  LEFT JOIN user_profiles actor ON actor.id = COALESCE(
    (a.details->>'updated_by')::uuid,
    (a.details->>'deleted_by')::uuid,
    a.user_id
  )
  WHERE a.user_id = p_user_id
  AND (
    -- Access control
    v.role = 'admin'
    OR (v.role = 'tenant_admin' AND v.tenant_id = (SELECT tenant_id FROM target_info))
    OR auth.uid() = p_user_id
  )
  AND (p_start_date IS NULL OR a.created_at >= p_start_date)
  AND (p_end_date IS NULL OR a.created_at <= p_end_date)
  AND (p_actions IS NULL OR a.action = ANY(p_actions))
  ORDER BY a.created_at DESC;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_stats TO authenticated;
GRANT EXECUTE ON FUNCTION search_users TO authenticated;
GRANT EXECUTE ON FUNCTION bulk_update_users TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_audit_log TO authenticated;