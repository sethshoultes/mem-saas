-- Function to get dashboard overview statistics
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_stats jsonb;
  v_viewer_role text;
  v_viewer_tenant_id uuid;
BEGIN
  -- Get viewer's role and tenant
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  -- Calculate statistics based on role
  WITH filtered_data AS (
    SELECT
      u.id as user_id,
      u.tenant_id,
      ms.status as subscription_status,
      mp.price * 
        CASE mp.interval
          WHEN 'monthly' THEN 1
          WHEN 'yearly' THEN 1/12.0
        END as monthly_price
    FROM user_profiles u
    LEFT JOIN member_subscriptions ms ON u.id = ms.user_id
    LEFT JOIN membership_plans mp ON ms.plan_id = mp.id
    WHERE 
      CASE v_viewer_role
        WHEN 'admin' THEN true
        WHEN 'tenant_admin' THEN u.tenant_id = v_viewer_tenant_id
        ELSE u.id = auth.uid()
      END
  )
  SELECT jsonb_build_object(
    'total_users', COUNT(DISTINCT user_id),
    'active_tenants', COUNT(DISTINCT tenant_id),
    'monthly_revenue', COALESCE(SUM(monthly_price) FILTER (WHERE subscription_status = 'active'), 0),
    'active_subscriptions', COUNT(*) FILTER (WHERE subscription_status = 'active')
  )
  INTO v_stats
  FROM filtered_data;

  RETURN v_stats;
END;
$$;

-- Function to get revenue data for charts
CREATE OR REPLACE FUNCTION get_revenue_data(months int DEFAULT 12)
RETURNS TABLE (
  month text,
  amount decimal
)
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
  WITH RECURSIVE months AS (
    SELECT 
      date_trunc('month', now()) as month_start
    UNION ALL
    SELECT 
      date_trunc('month', month_start - interval '1 month')
    FROM months
    WHERE date_trunc('month', month_start - interval '1 month') > date_trunc('month', now() - interval '12 months')
  ),
  filtered_subscriptions AS (
    SELECT 
      ms.current_period_start,
      mp.price * 
        CASE mp.interval
          WHEN 'monthly' THEN 1
          WHEN 'yearly' THEN 1/12.0
        END as monthly_price
    FROM member_subscriptions ms
    JOIN membership_plans mp ON ms.plan_id = mp.id
    JOIN user_profiles u ON ms.user_id = u.id
    WHERE ms.status = 'active'
    AND CASE v_viewer_role
      WHEN 'admin' THEN true
      WHEN 'tenant_admin' THEN u.tenant_id = v_viewer_tenant_id
      ELSE u.id = auth.uid()
    END
  )
  SELECT 
    to_char(m.month_start, 'Mon YYYY') as month,
    COALESCE(SUM(fs.monthly_price), 0) as amount
  FROM months m
  LEFT JOIN filtered_subscriptions fs 
    ON date_trunc('month', fs.current_period_start) = m.month_start
  GROUP BY m.month_start
  ORDER BY m.month_start;
END;
$$;

-- Function to get subscription status distribution
CREATE OR REPLACE FUNCTION get_subscription_distribution()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_viewer_role text;
  v_viewer_tenant_id uuid;
  v_distribution jsonb;
BEGIN
  -- Get viewer's role and tenant
  SELECT role, tenant_id INTO v_viewer_role, v_viewer_tenant_id
  FROM user_profiles
  WHERE id = auth.uid();

  SELECT jsonb_build_object(
    'active', COUNT(*) FILTER (WHERE ms.status = 'active'),
    'canceled', COUNT(*) FILTER (WHERE ms.status = 'canceled'),
    'past_due', COUNT(*) FILTER (WHERE ms.status = 'past_due')
  )
  INTO v_distribution
  FROM member_subscriptions ms
  JOIN user_profiles u ON ms.user_id = u.id
  WHERE CASE v_viewer_role
    WHEN 'admin' THEN true
    WHEN 'tenant_admin' THEN u.tenant_id = v_viewer_tenant_id
    ELSE u.id = auth.uid()
  END;

  RETURN v_distribution;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_dashboard_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_revenue_data TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_distribution TO authenticated;