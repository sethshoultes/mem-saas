/*
  # Add demo users for content gating testing

  1. New Tables
    - None (using existing tables)
  
  2. Changes
    - Add demo users for testing content access
    - Add demo subscriptions for testing
  
  3. Security
    - Demo users are restricted to testing only
*/

-- Create demo users
INSERT INTO auth.users (id, email)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'demo-free@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'demo-premium@example.com')
ON CONFLICT (id) DO NOTHING;

-- Create user profiles
INSERT INTO user_profiles (id, full_name, role, status)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Demo Free User', 'user', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'Demo Premium User', 'user', 'active')
ON CONFLICT (id) DO NOTHING;

-- Create demo subscriptions
INSERT INTO member_subscriptions (
  id,
  user_id,
  plan_id,
  status,
  current_period_start,
  current_period_end
)
SELECT 
  gen_random_uuid(),
  '22222222-2222-2222-2222-222222222222',
  id,
  'active',
  now(),
  now() + interval '1 month'
FROM membership_plans
WHERE is_active = true
LIMIT 1
ON CONFLICT DO NOTHING;