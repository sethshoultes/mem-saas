import React, { useState } from 'react';
import { Button } from '../ui/button';
import { AlertCircle, Loader2, Send } from 'lucide-react';
import { WEBHOOK_EVENTS } from '../../lib/webhook-events';
import { deliverWebhook } from '../../lib/mock-payment';

interface WebhookSimulatorProps {
  onWebhookSent?: () => void;
}

export function WebhookSimulator({ onWebhookSent }: WebhookSimulatorProps) {
  const [selectedEvent, setSelectedEvent] = useState<string>('');
  const [isDelivering, setIsDelivering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deliveryStatus, setDeliveryStatus] = useState<{
    success: boolean;
    message: string;
  } | null>(null);

  const handleDeliverWebhook = async () => {
    if (!selectedEvent) return;

    setIsDelivering(true);
    setError(null);
    setDeliveryStatus(null);

    try {
      const webhookId = await deliverWebhook(selectedEvent);
      setDeliveryStatus({
        success: true,
        message: `Webhook delivered successfully (ID: ${webhookId})`
      });
      onWebhookSent?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to deliver webhook');
    } finally {
      setIsDelivering(false);
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold text-gray-900">Webhook Simulator</h2>
        <p className="text-sm text-gray-500">
          Test webhook delivery and event handling
        </p>
      </div>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Select Event Type
          </label>
          <select
            className="w-full rounded-md border border-gray-300 px-3 py-2"
            value={selectedEvent}
            onChange={(e) => setSelectedEvent(e.target.value)}
          >
            <option value="">Select an event...</option>
            {Object.entries(WEBHOOK_EVENTS).map(([event, { description }]) => (
              <option key={event} value={event}>
                {event} - {description}
              </option>
            ))}
          </select>
        </div>

        {selectedEvent && (
          <div className="bg-gray-50 rounded-lg p-4">
            <h3 className="text-sm font-medium text-gray-900 mb-2">Event Data</h3>
            <pre className="text-sm text-gray-600 overflow-auto">
              {JSON.stringify(WEBHOOK_EVENTS[selectedEvent as keyof typeof WEBHOOK_EVENTS].data, null, 2)}
            </pre>
          </div>
        )}

        <Button
          onClick={handleDeliverWebhook}
          disabled={!selectedEvent || isDelivering}
          className="w-full"
        >
          {isDelivering ? (
            <>
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              Delivering Webhook...
            </>
          ) : (
            <>
              <Send className="h-4 w-4 mr-2" />
              Deliver Webhook
            </>
          )}
        </Button>

        {error && (
          <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
            <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
            <p className="text-sm text-red-600">{error}</p>
          </div>
        )}

        {deliveryStatus && (
          <div className={`p-4 rounded-lg flex items-start gap-3 ${
            deliveryStatus.success ? 'bg-green-50' : 'bg-red-50'
          }`}>
            <AlertCircle className={`h-5 w-5 ${
              deliveryStatus.success ? 'text-green-500' : 'text-red-500'
            } mt-0.5`} />
            <p className={`text-sm ${
              deliveryStatus.success ? 'text-green-600' : 'text-red-600'
            }`}>{deliveryStatus.message}</p>
          </div>
        )}
      </div>
    </div>
  );
}