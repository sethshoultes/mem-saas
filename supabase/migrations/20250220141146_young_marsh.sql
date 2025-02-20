/*
  # Mock Payment System Tables and Functions

  1. New Tables
    - mock_transactions: Stores simulated payment transactions
    - mock_payment_methods: Stores test payment methods
    - mock_webhooks: Stores webhook events for replay/testing

  2. Functions
    - process_mock_payment: Simulates payment processing
*/

-- Mock transaction storage
CREATE TABLE IF NOT EXISTS mock_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  amount decimal NOT NULL,
  currency text DEFAULT 'usd',
  status text CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method_id text,
  error_code text,
  error_message text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Mock payment methods
CREATE TABLE IF NOT EXISTS mock_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  type text DEFAULT 'card',
  card_number text,
  exp_month integer,
  exp_year integer,
  created_at timestamptz DEFAULT now()
);

-- Mock webhook events
CREATE TABLE IF NOT EXISTS mock_webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id),
  event_type text NOT NULL,
  data jsonb NOT NULL,
  processed boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Process mock payment
CREATE OR REPLACE FUNCTION process_mock_payment(
  p_tenant_id uuid,
  p_amount decimal,
  p_card_number text,
  p_currency text DEFAULT 'usd',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_transaction_id uuid;
  v_status text;
  v_error_code text;
  v_error_message text;
BEGIN
  -- Simulate payment processing based on test card numbers
  CASE p_card_number
    WHEN '4242424242424242' THEN
      v_status := 'completed';
    WHEN '4000000000000002' THEN
      v_status := 'failed';
      v_error_code := 'card_declined';
      v_error_message := 'Your card was declined';
    WHEN '4000000000009995' THEN
      v_status := 'failed';
      v_error_code := 'insufficient_funds';
      v_error_message := 'Insufficient funds';
    ELSE
      v_status := 'failed';
      v_error_code := 'invalid_card';
      v_error_message := 'Invalid card number';
  END CASE;

  -- Create transaction record
  INSERT INTO mock_transactions (
    tenant_id,
    amount,
    currency,
    status,
    payment_method_id,
    error_code,
    error_message,
    metadata
  ) VALUES (
    p_tenant_id,
    p_amount,
    p_currency,
    v_status,
    p_card_number,
    v_error_code,
    v_error_message,
    p_metadata
  )
  RETURNING id INTO v_transaction_id;

  -- Create webhook event
  INSERT INTO mock_webhooks (
    tenant_id,
    event_type,
    data
  ) VALUES (
    p_tenant_id,
    CASE v_status
      WHEN 'completed' THEN 'payment_intent.succeeded'
      ELSE 'payment_intent.failed'
    END,
    jsonb_build_object(
      'transaction_id', v_transaction_id,
      'amount', p_amount,
      'currency', p_currency,
      'status', v_status,
      'error', CASE 
        WHEN v_error_code IS NOT NULL THEN
          jsonb_build_object(
            'code', v_error_code,
            'message', v_error_message
          )
        ELSE NULL
      END
    )
  );

  RETURN jsonb_build_object(
    'id', v_transaction_id,
    'status', v_status,
    'error', CASE 
      WHEN v_error_code IS NOT NULL THEN
        jsonb_build_object(
          'code', v_error_code,
          'message', v_error_message
        )
      ELSE NULL
    END
  );
END;
$$;