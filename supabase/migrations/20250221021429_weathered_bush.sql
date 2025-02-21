/*
  # Set up demo environment for content gating

  1. Demo Setup
    - Create demo tenant
    - Associate demo users with tenant
    - Create demo membership plans
    - Set up demo subscriptions
    - Create demo content
    - Configure access rules

  2. Changes
    - Add demo tenant for testing
    - Link demo users to tenant
    - Create basic and premium plans
    - Set up subscriptions for premium user
    - Add sample content with access rules
*/

-- Create demo tenant
INSERT INTO tenants (id, name, status, subscription_status)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  'Demo Tenant',
  'active',
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Associate demo users with tenant
UPDATE user_profiles
SET tenant_id = '33333333-3333-3333-3333-333333333333'
WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);

-- Create demo membership plans
INSERT INTO membership_plans (
  id,
  tenant_id,
  name,
  description,
  price,
  interval,
  features,
  is_active
) VALUES 
(
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333',
  'Basic Plan',
  'Access to basic content',
  9.99,
  'monthly',
  '["Basic content access", "Preview premium content"]',
  true
),
(
  '55555555-5555-5555-5555-555555555555',
  '33333333-3333-3333-3333-333333333333',
  'Premium Plan',
  'Full access to all content',
  19.99,
  'monthly',
  '["Full content access", "Premium features", "Early access"]',
  true
) ON CONFLICT (id) DO NOTHING;

-- Set up premium subscription for demo premium user
INSERT INTO member_subscriptions (
  id,
  user_id,
  plan_id,
  status,
  current_period_start,
  current_period_end
) VALUES (
  '66666666-6666-6666-6666-666666666666',
  '22222222-2222-2222-2222-222222222222',
  '55555555-5555-5555-5555-555555555555',
  'active',
  now(),
  now() + interval '1 month'
) ON CONFLICT (id) DO NOTHING;

-- Create demo content
INSERT INTO content_items (
  id,
  tenant_id,
  title,
  description,
  content_type,
  content,
  preview_content,
  is_published
) VALUES (
  '77777777-7777-7777-7777-777777777777',
  '33333333-3333-3333-3333-333333333333',
  'Premium Article',
  'A premium article demonstrating content gating',
  'text',
  'This is the full premium content that only premium subscribers can access. It contains valuable information and insights that make the subscription worthwhile.',
  'This is a preview of the premium content. Subscribe to our premium plan to read the full article and access all premium features!',
  true
) ON CONFLICT (id) DO NOTHING;

-- Set up access rules
INSERT INTO content_access (
  content_id,
  plan_id,
  access_type
) VALUES 
-- Basic plan gets preview access
(
  '77777777-7777-7777-7777-777777777777',
  '44444444-4444-4444-4444-444444444444',
  'preview'
),
-- Premium plan gets full access
(
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  'full'
) ON CONFLICT DO NOTHING;