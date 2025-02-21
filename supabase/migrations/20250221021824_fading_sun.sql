/*
  # Set up demo access levels

  1. Changes
    - Add access rules for demo content
    - Link plans to content access
    - Set up proper preview content
*/

-- Update demo content with proper preview
UPDATE content_items
SET 
  content = 'This is the full premium content that demonstrates the value of a premium subscription. It includes detailed insights, analysis, and exclusive information that makes the subscription worthwhile. Premium members get access to all features and content without restrictions.',
  preview_content = 'This is a preview of our premium content. Get a taste of what''s available with a premium subscription. Upgrade to access the full article and all premium features!'
WHERE id = '77777777-7777-7777-7777-777777777777';

-- Clear existing access rules
DELETE FROM content_access
WHERE content_id = '77777777-7777-7777-7777-777777777777';

-- Set up proper access rules
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
);