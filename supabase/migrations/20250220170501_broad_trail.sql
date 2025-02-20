/*
  # Add Webhook Delivery Tracking

  1. Changes
    - Add webhook delivery tracking fields to mock_webhooks table
    - Add webhook delivery log table for detailed tracking
    - Add function to log webhook delivery attempts

  2. New Tables
    - `mock_webhook_delivery_logs`
      - `id` (uuid, primary key)
      - `webhook_id` (uuid, references mock_webhooks)
      - `attempt_number` (integer)
      - `status` (text)
      - `error_message` (text)
      - `created_at` (timestamptz)

  3. Security
    - Grant access to authenticated users
*/

-- Create webhook delivery log table
CREATE TABLE IF NOT EXISTS mock_webhook_delivery_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id uuid REFERENCES mock_webhooks(id),
  attempt_number integer NOT NULL,
  status text NOT NULL CHECK (status IN ('success', 'failed')),
  error_message text,
  created_at timestamptz DEFAULT now()
);

-- Function to log webhook delivery attempt
CREATE OR REPLACE FUNCTION log_webhook_delivery_attempt(
  p_webhook_id uuid,
  p_attempt_number integer,
  p_status text,
  p_error_message text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO mock_webhook_delivery_logs (
    webhook_id,
    attempt_number,
    status,
    error_message,
    created_at
  ) VALUES (
    p_webhook_id,
    p_attempt_number,
    p_status,
    p_error_message,
    now()
  )
  RETURNING id INTO v_log_id;

  -- Update webhook status
  UPDATE mock_webhooks
  SET 
    delivery_attempts = p_attempt_number,
    last_attempt_at = now(),
    delivered_at = CASE WHEN p_status = 'success' THEN now() ELSE delivered_at END
  WHERE id = p_webhook_id;

  RETURN v_log_id;
END;
$$;

-- Grant necessary permissions
GRANT ALL ON mock_webhook_delivery_logs TO authenticated;
GRANT EXECUTE ON FUNCTION log_webhook_delivery_attempt TO authenticated;