import { supabase } from './supabase';
import { WEBHOOK_EVENTS } from '../lib/webhook-events';

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
  // Add random delay to simulate network latency
  await simulateNetworkDelay();

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

// Simulate network conditions and errors
async function simulateNetworkDelay() {
  const shouldFail = Math.random() < 0.05; // 5% chance of network error
  const delay = Math.random() * 1000 + 200; // 200-1200ms delay

  await new Promise((resolve, reject) => {
    setTimeout(() => {
      if (shouldFail) {
        reject(new Error('Network error: Connection timeout'));
      } else {
        resolve(undefined);
      }
    }, delay);
  });
}

// Enhanced webhook delivery with retry logic
export async function deliverWebhook(
  eventType: string,
  maxRetries: number = 3
): Promise<boolean> {
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

  // Create webhook event
  const { data: webhook, error: createError } = await supabase
    .rpc('create_webhook_event', {
      p_tenant_id: profile.tenant_id,
      p_event_type: eventType,
      p_data: WEBHOOK_EVENTS[eventType as keyof typeof WEBHOOK_EVENTS].data
    });

  if (createError) throw createError;

  let attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      await simulateNetworkDelay();
      
      // Log delivery attempt
      const { error: logError } = await supabase
        .rpc('log_webhook_delivery_attempt', {
          p_webhook_id: webhook,
          p_attempt_number: attempts + 1,
          p_status: 'success'
        });

      if (logError) throw logError;
      
      const { data, error } = await supabase
        .from('mock_webhooks')
        .update({
          processed: true
        })
        .eq('id', webhook)
        .select()
        .single();

      if (error) throw error;
      return true;
    } catch (error) {
      attempts++;
      if (attempts === maxRetries) {
        console.error(`Webhook delivery failed after ${maxRetries} attempts:`, error);
        
        // Log failed attempt
        await supabase.rpc('log_webhook_delivery_attempt', {
          p_webhook_id: webhook,
          p_attempt_number: attempts,
          p_status: 'failed',
          p_error_message: error instanceof Error ? error.message : 'Webhook delivery failed'
        });
        
        return false;
      }
      // Exponential backoff
      await new Promise(resolve => 
        setTimeout(resolve, Math.pow(2, attempts) * 1000)
      );
    }
  }
  return false;
}

export async function refundMockTransaction(transactionId: string) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  await simulateNetworkDelay();

  // Get original transaction
  const { data: transaction, error: txError } = await supabase
    .from('mock_transactions')
    .eq('id', transactionId)
    .select()
    .single();

  if (txError) throw txError;
  if (!transaction) throw new Error('Transaction not found');

  // Create refund transaction
  const { data: refund, error } = await supabase
    .from('mock_transactions')
    .insert({
      tenant_id: transaction.tenant_id,
      amount: -transaction.amount,
      currency: transaction.currency,
      status: 'completed',
      payment_method_id: transaction.payment_method_id,
      metadata: {
        ...transaction.metadata,
        refund_for: transactionId
      }
    })
    .select()
    .single();

  if (error) throw error;

  // Update original transaction
  await supabase
    .from('mock_transactions')
    .update({ status: 'refunded' })
    .eq('id', transactionId);

  // Create webhook event
  const { error: webhookError } = await supabase
    .from('mock_webhooks')
    .insert({
      tenant_id: transaction.tenant_id,
      event_type: 'charge.refunded',
      data: {
        transaction_id: transactionId,
        refund_id: refund.id,
        amount: transaction.amount
      }
    });

  if (webhookError) throw webhookError;
  return refund;
}

export async function getTransactionHistory(
  tenantId: string,
  filters: {
    status?: string[];
    startDate?: Date;
    endDate?: Date;
  } = {}
) {
  let query = supabase
    .from('mock_transactions')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });

  if (filters.status?.length) {
    query = query.in('status', filters.status);
  }

  if (filters.startDate) {
    query = query.gte('created_at', filters.startDate.toISOString());
  }

  if (filters.endDate) {
    query = query.lte('created_at', filters.endDate.toISOString());
  }

  const { data, error } = await query;
  if (error) throw error;
  return data;
}