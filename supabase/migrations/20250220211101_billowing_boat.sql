/*
  # Content Gating Implementation

  1. Schema Updates
    - Add preview_content to content_items
    - Add access_type to content_access
    - Add indexes for performance

  2. Functions
    - Content access verification
    - Preview content management
    - Access rule management
*/

-- Add preview content to content items
ALTER TABLE content_items
ADD COLUMN preview_content text;

-- Update content access table
ALTER TABLE content_access
ADD COLUMN access_type text NOT NULL DEFAULT 'full'
CHECK (access_type IN ('full', 'preview'));

-- Add indexes for performance
CREATE INDEX idx_content_access_content_id ON content_access(content_id);
CREATE INDEX idx_content_access_plan_id ON content_access(plan_id);
CREATE INDEX idx_content_items_tenant_id ON content_items(tenant_id);

-- Function to verify content access
CREATE OR REPLACE FUNCTION verify_content_access(
  p_content_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH user_plans AS (
    SELECT DISTINCT plan_id
    FROM member_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
  ),
  access_rules AS (
    SELECT DISTINCT access_type
    FROM content_access ca
    JOIN user_plans up ON ca.plan_id = up.plan_id
    WHERE ca.content_id = p_content_id
  )
  SELECT jsonb_build_object(
    'has_access', CASE WHEN COUNT(*) > 0 THEN true ELSE false END,
    'access_type', MAX(access_type)
  )
  INTO v_result
  FROM access_rules;

  RETURN COALESCE(v_result, jsonb_build_object(
    'has_access', false,
    'access_type', null
  ));
END;
$$;

-- Function to get content with access check
CREATE OR REPLACE FUNCTION get_content_with_access(
  p_content_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_access jsonb;
  v_content jsonb;
BEGIN
  -- Check access
  v_access := verify_content_access(p_content_id, p_user_id);
  
  -- Get content based on access level
  SELECT jsonb_build_object(
    'id', id,
    'title', title,
    'content', CASE 
      WHEN (v_access->>'access_type') = 'full' THEN content
      WHEN (v_access->>'access_type') = 'preview' THEN COALESCE(preview_content, substring(content, 1, 500) || '...')
      ELSE NULL
    END,
    'access_level', v_access->>'access_type'
  )
  INTO v_content
  FROM content_items
  WHERE id = p_content_id;

  RETURN v_content;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION verify_content_access TO authenticated;
GRANT EXECUTE ON FUNCTION get_content_with_access TO authenticated;