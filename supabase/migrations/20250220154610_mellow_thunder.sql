/*
  # Fix webhook system and add event tracking

  1. Changes
    - Add webhook_events table to track event types
    - Update mock_webhooks table to reference event types
    - Add functions for webhook event management
    - Add webhook delivery tracking

  2. Security
    - Grant access to authenticated users
*/

-- Create webhook events table
CREATE TABLE IF NOT EXISTS mock_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL UNIQUE,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Add initial event types
INSERT INTO mock_webhook_events (type, description) VALUES
  ('payment_intent.succeeded', 'Payment succeeded'),
  ('payment_intent.failed', 'Payment failed'),
  ('charge.refunded', 'Charge refunded')
ON CONFLICT (type) DO NOTHING;

-- Update mock_webhooks table
ALTER TABLE mock_webhooks
  ADD COLUMN event_id uuid REFERENCES mock_webhook_events(id),
  ADD COLUMN delivery_attempts integer DEFAULT 0,
  ADD COLUMN last_attempt_at timestamptz,
  ADD COLUMN delivered_at timestamptz;

-- Function to create and deliver webhook
CREATE OR REPLACE FUNCTION create_webhook_event(
  p_tenant_id uuid,
  p_event_type text,
  p_data jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id uuid;
  v_webhook_id uuid;
BEGIN
  -- Get event ID
  SELECT id INTO v_event_id
  FROM mock_webhook_events
  WHERE type = p_event_type;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'Invalid webhook event type: %', p_event_type;
  END IF;

  -- Create webhook
  INSERT INTO mock_webhooks (
    tenant_id,
    event_id,
    event_type,
    data,
    created_at
  ) VALUES (
    p_tenant_id,
    v_event_id,
    p_event_type,
    p_data,
    now()
  )
  RETURNING id INTO v_webhook_id;

  RETURN v_webhook_id;
END;
$$;