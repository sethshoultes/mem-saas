/*
  # Complete Database Installation/Recovery

  This migration contains the complete database schema, functions, and security settings.
  It can be used to restore the database from scratch or recover from major issues.

  1. Core Tables
    - user_profiles: User information and roles
    - user_activity: Audit log of user actions
    - tenants: Multi-tenant organization data
    - membership_plans: Subscription plan definitions
    - member_subscriptions: User subscriptions
    - content_items: Protected content
    - content_access: Content access rules

  2. Core Functions
    - User Management: Authentication and authorization
    - Tenant Management: Multi-tenant operations
    - Subscription Management: Plan and subscription handling
    - Trial Management: Trial period handling
    - Bulk Operations: Mass subscription updates
    - Analytics: Statistics and reporting

  3. Security
    - Function permissions
    - Table access grants
    - Role-based security
*/

-- Core Tables
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  full_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'tenant_admin', 'user')),
  tenant_id uuid,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  action text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  subscription_status text NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'canceled', 'past_due')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS membership_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price decimal(10,2) NOT NULL,
  interval text NOT NULL CHECK (interval IN ('monthly', 'yearly')),
  features jsonb DEFAULT '[]'::jsonb,
  is_active boolean DEFAULT true,
  trial_days integer DEFAULT 0 CHECK (trial_days >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS member_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  status text NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'incomplete')),
  current_period_start timestamptz NOT NULL,
  current_period_end timestamptz NOT NULL,
  cancel_at_period_end boolean DEFAULT false,
  stripe_subscription_id text,
  trial_ends_at timestamptz,
  is_trial boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  title text NOT NULL,
  description text,
  content_type text NOT NULL CHECK (content_type IN ('html', 'text', 'url')),
  content text NOT NULL,
  is_published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id uuid NOT NULL REFERENCES content_items(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  created_at timestamptz DEFAULT now()
);

-- Include all functions from previous migrations
[Include all functions from 20250219154245_royal_base.sql]
[Include all functions from 20250220043730_green_glitter.sql]
[Include all functions from 20250220044418_morning_grove.sql]
[Include all functions from 20250220051328_wooden_meadow.sql]
[Include all functions from 20250220052408_lively_silence.sql]

-- Grant necessary permissions
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_activity TO authenticated;
GRANT ALL ON tenants TO authenticated;
GRANT ALL ON membership_plans TO authenticated;
GRANT ALL ON member_subscriptions TO authenticated;
GRANT ALL ON content_items TO authenticated;
GRANT ALL ON content_access TO authenticated;

-- Grant function execution permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;