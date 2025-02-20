import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { formatDate } from '../../lib/utils';
import { AlertCircle, CheckCircle, RefreshCw, Loader2 } from 'lucide-react';
import { Button } from '../ui/button';
import { WebhookSimulator } from './WebhookSimulator';

interface WebhookLog {
  id: string;
  event_type: string;
  data: any;
  delivery_attempts: number;
  last_attempt_at: string;
  delivered_at: string | null;
  created_at: string;
  logs: {
    attempt_number: number;
    status: 'success' | 'failed';
    error_message: string | null;
    created_at: string;
  }[];
}

export function WebhookLogViewer() {
  const [logs, setLogs] = useState<WebhookLog[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchLogs = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const { data: webhooks, error: webhooksError } = await supabase
        .from('mock_webhooks')
        .select(`
          id,
          event_type,
          data,
          delivery_attempts,
          last_attempt_at,
          delivered_at,
          created_at,
          mock_webhook_delivery_logs (
            attempt_number,
            status,
            error_message,
            created_at
          )
        `)
        .order('created_at', { ascending: false })
        .limit(10);

      if (webhooksError) throw webhooksError;

      setLogs(webhooks.map(webhook => ({
        ...webhook,
        logs: webhook.mock_webhook_delivery_logs || []
      })));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch webhook logs');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Recent Webhooks</h2>
            <Button
              variant="secondary"
              size="sm"
              onClick={fetchLogs}
              disabled={isLoading}
            >
              {isLoading ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <RefreshCw className="h-4 w-4" />
              )}
            </Button>
          </div>

          {error && (
            <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
              <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <div className="space-y-4">
        {logs.map(log => (
          <div key={log.id} className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div className="p-4 flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-sm text-gray-500">{log.id}</span>
                  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                    log.delivered_at ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'
                  }`}>
                    {log.delivered_at ? 'Delivered' : 'Pending'}
                  </span>
                </div>
                <div className="mt-1 font-medium text-gray-900">{log.event_type}</div>
                <div className="mt-2 text-sm text-gray-500">
                  Created: {formatDate(new Date(log.created_at))}
                </div>
              </div>
              <div className="text-right text-sm text-gray-500">
                <div>Attempts: {log.delivery_attempts}</div>
                {log.delivered_at && (
                  <div className="text-green-600">
                    Delivered: {formatDate(new Date(log.delivered_at))}
                  </div>
                )}
              </div>
            </div>

            {log.logs.length > 0 && (
              <div className="border-t border-gray-100">
                <div className="p-4">
                  <h4 className="text-sm font-medium text-gray-900 mb-2">Delivery Attempts</h4>
                  <div className="space-y-2">
                    {log.logs.map((attempt, index) => (
                      <div
                        key={index}
                        className="flex items-start gap-2 text-sm"
                      >
                        {attempt.status === 'success' ? (
                          <CheckCircle className="h-4 w-4 text-green-500 mt-1" />
                        ) : (
                          <AlertCircle className="h-4 w-4 text-red-500 mt-1" />
                        )}
                        <div>
                          <div className={attempt.status === 'success' ? 'text-green-600' : 'text-red-600'}>
                            Attempt {attempt.attempt_number}: {attempt.status}
                          </div>
                          {attempt.error_message && (
                            <div className="text-red-600 mt-1">{attempt.error_message}</div>
                          )}
                          <div className="text-gray-500 text-xs mt-1">
                            {formatDate(new Date(attempt.created_at))}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            <div className="border-t border-gray-100 bg-gray-50 p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="text-sm font-medium text-gray-900">Event Data</h4>
              </div>
              <pre className="text-xs text-gray-600 overflow-auto">
                {JSON.stringify(log.data, null, 2)}
              </pre>
            </div>
          </div>
        ))}
          </div>
        </div>

        <div className="space-y-6">
          <WebhookSimulator onWebhookSent={fetchLogs} />
        </div>
      </div>
    </div>
  );
}