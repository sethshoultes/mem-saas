/*
  # Create membership and content management tables

  1. New Tables
    - `membership_plans`
      - Stores different membership tiers and their configurations
    - `member_subscriptions`
      - Tracks user subscriptions to membership plans
    - `content_items`
      - Stores gated content information
    - `content_access`
      - Maps content items to membership plans

  2. Security
    - Enable RLS on all tables
    - Add policies for proper access control
*/

-- Membership Plans Table
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS membership_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES auth.users(id),
    name text NOT NULL,
    description text,
    price decimal(10,2) NOT NULL,
    interval text NOT NULL CHECK (interval IN ('monthly', 'yearly')),
    features jsonb DEFAULT '[]'::jsonb,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

ALTER TABLE membership_plans ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Tenants can manage their own membership plans" ON membership_plans;
  CREATE POLICY "Tenants can manage their own membership plans"
    ON membership_plans
    FOR ALL
    TO authenticated
    USING (auth.uid() = tenant_id);
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Member Subscriptions Table
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS member_subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    plan_id uuid NOT NULL REFERENCES membership_plans(id),
    status text NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'incomplete')),
    current_period_start timestamptz NOT NULL,
    current_period_end timestamptz NOT NULL,
    cancel_at_period_end boolean DEFAULT false,
    stripe_subscription_id text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

ALTER TABLE member_subscriptions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can view their own subscriptions" ON member_subscriptions;
  CREATE POLICY "Users can view their own subscriptions"
    ON member_subscriptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Tenants can view their plan subscriptions" ON member_subscriptions;
  CREATE POLICY "Tenants can view their plan subscriptions"
    ON member_subscriptions
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM membership_plans
        WHERE membership_plans.id = member_subscriptions.plan_id
        AND membership_plans.tenant_id = auth.uid()
      )
    );
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Content Items Table
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS content_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES auth.users(id),
    title text NOT NULL,
    description text,
    content_type text NOT NULL CHECK (content_type IN ('html', 'text', 'url')),
    content text NOT NULL,
    is_published boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Tenants can manage their own content" ON content_items;
  CREATE POLICY "Tenants can manage their own content"
    ON content_items
    FOR ALL
    TO authenticated
    USING (auth.uid() = tenant_id);
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Content Access Table
DO $$ BEGIN
  CREATE TABLE IF NOT EXISTS content_access (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id uuid NOT NULL REFERENCES content_items(id),
    plan_id uuid NOT NULL REFERENCES membership_plans(id),
    created_at timestamptz DEFAULT now()
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

ALTER TABLE content_access ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Tenants can manage content access" ON content_access;
  CREATE POLICY "Tenants can manage content access"
    ON content_access
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM content_items
        WHERE content_items.id = content_access.content_id
        AND content_items.tenant_id = auth.uid()
      )
    );
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Add function to check content access
CREATE OR REPLACE FUNCTION check_content_access(p_content_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM content_access ca
    JOIN member_subscriptions ms ON ca.plan_id = ms.plan_id
    WHERE ca.content_id = p_content_id
    AND ms.user_id = p_user_id
    AND ms.status = 'active'
    AND ms.current_period_end > now()
  );
END;
$$;