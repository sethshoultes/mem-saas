import { supabase } from './supabase';

export const TEST_CARDS = {
  success: '4242424242424242',
  decline: '4000000000000002',
  insufficient_funds: '4000000000009995',
  expired: '4000000000000069',
  incorrect_cvc: '4000000000000127',
  processing_error: '4000000000000119'
} as const;

interface MockPaymentResult {
  id: string;
  status: 'completed' | 'failed';
  error?: {
    code: string;
    message: string;
  };
}

export async function processMockPayment(
  amount: number,
  cardNumber: string,
  metadata: Record<string, any> = {}
): Promise<MockPaymentResult> {
  // Add random delay to simulate processing
  await new Promise(resolve => 
    setTimeout(resolve, Math.random() * 1000 + 500)
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // Get tenant ID
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('tenant_id')
    .eq('id', user.id)
    .single();

  if (!profile?.tenant_id) {
    throw new Error('No tenant ID found');
  }

  // Process payment through mock system
  const { data, error } = await supabase.rpc('process_mock_payment', {
    p_tenant_id: profile.tenant_id,
    p_amount: amount,
    p_card_number: cardNumber,
    p_metadata: metadata
  });

  if (error) throw error;
  return data;
}

export async function setupMockWebhookListener(
  onEvent: (event: {
    type: string;
    data: any;
  }) => void
) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // Get tenant ID
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('tenant_id')
    .eq('id', user.id)
    .single();

  if (!profile?.tenant_id) {
    throw new Error('No tenant ID found');
  }

  // Subscribe to webhook events
  const subscription = supabase
    .channel('mock-webhooks')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'mock_webhooks',
        filter: `tenant_id=eq.${profile.tenant_id}`
      },
      (payload) => {
        onEvent({
          type: payload.new.event_type,
          data: payload.new.data
        });
      }
    )
    .subscribe();

  return () => {
    subscription.unsubscribe();
  };
}

export async function getMockTransactions(
  status?: 'completed' | 'failed' | 'refunded'
) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  let query = supabase
    .from('mock_transactions')
    .select('*')
    .order('created_at', { ascending: false });

  if (status) {
    query = query.eq('status', status);
  }

  const { data, error } = await query;
  if (error) throw error;
  return data;
}

export async function refundMockTransaction(transactionId: string) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // Add random delay
  await new Promise(resolve => 
    setTimeout(resolve, Math.random() * 500 + 200)
  );

  const { data, error } = await supabase
    .from('mock_transactions')
    .update({ status: 'refunded' })
    .eq('id', transactionId)
    .select()
    .single();

  if (error) throw error;
  return data;
}