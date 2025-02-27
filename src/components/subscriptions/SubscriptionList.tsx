import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Button } from '../ui/button';
import { BulkActions } from './BulkActions';
import { Search, Filter, CreditCard, AlertCircle, Trash2, Loader2, Plus, ArrowUpDown } from 'lucide-react';
import { formatDate, formatCurrency } from '../../lib/utils';
import { cancelSubscription, reactivateSubscription, retrySubscriptionPayment, upgradeSubscription, downgradeSubscription, processTrialExpiration } from '../../lib/subscriptions';
import { CreateSubscriptionModal } from './CreateSubscriptionModal';
import { UpgradeSubscriptionModal } from './UpgradeSubscriptionModal';

interface Subscription {
  subscription_id: string;
  user_id: string;
  user_name: string;
  plan_id: string;
  plan_name: string;
  status: string;
  is_trial: boolean;
  trial_ends_at: string | null;
  current_period_end: string;
  amount: number;
}

export function SubscriptionList() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedSubscriptions, setSelectedSubscriptions] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'canceled' | 'past_due' | 'trial'>('all');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [processingSubscriptionId, setProcessingSubscriptionId] = useState<string | null>(null);
  const [isUpgradeModalOpen, setIsUpgradeModalOpen] = useState(false);
  const [selectedSubscription, setSelectedSubscription] = useState<Subscription | null>(null);

  useEffect(() => {
    fetchSubscriptions();
  }, []);

  async function fetchSubscriptions() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Get user's tenant_id first
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('tenant_id')
        .eq('id', user.id)
        .single();

      if (!profile?.tenant_id) return;

      const { data, error } = await supabase
        .rpc('get_tenant_subscriptions', {
          p_tenant_id: profile.tenant_id
        });

      if (error) throw error;
      setSubscriptions(data || []);
    } catch (error) {
      console.error('Error fetching subscriptions:', error);
    } finally {
      setIsLoading(false);
    }
  }

  const filteredSubscriptions = subscriptions.filter(subscription => {
    const matchesSearch = subscription.user_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         subscription.plan_name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'all' || 
                          (statusFilter === 'trial' && subscription.is_trial) || 
                          subscription.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const handleSubscriptionSelect = (subscriptionId: string, isSelected: boolean) => {
    if (isSelected) {
      setSelectedSubscriptions([...selectedSubscriptions, subscriptionId]);
    } else {
      setSelectedSubscriptions(selectedSubscriptions.filter(id => id !== subscriptionId));
    }
  };

  const handleSelectAll = (isSelected: boolean) => {
    setSelectedSubscriptions(isSelected ? filteredSubscriptions.map(s => s.subscription_id) : []);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-700';
      case 'canceled':
        return 'bg-red-100 text-red-700';
      case 'past_due':
        return 'bg-yellow-100 text-yellow-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  if (isLoading) {
    return <div className="flex justify-center p-8">Loading subscriptions...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Subscriptions</h1>
        <Button onClick={() => setIsCreateModalOpen(true)}>
          <Plus className="h-4 w-4 mr-2" />
          Create Subscription
        </Button>
      </div>

      {selectedSubscriptions.length > 0 && (
        <BulkActions
          selectedSubscriptions={selectedSubscriptions}
          onClearSelection={() => setSelectedSubscriptions([])}
          onRefresh={fetchSubscriptions}
        />
      )}

      <div className="flex gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search subscriptions..."
            className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select
            className="border border-gray-200 rounded-lg px-3 py-2"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
          >
            <option value="all">All Status</option>
            <option value="active">Active</option>
            <option value="canceled">Canceled</option>
            <option value="past_due">Past Due</option>
            <option value="trial">Trial</option>
          </select>
        </div>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <input
                    type="checkbox"
                    className="h-4 w-4 text-blue-600 rounded border-gray-300"
                    checked={selectedSubscriptions.length === filteredSubscriptions.length}
                    onChange={(e) => handleSelectAll(e.target.checked)}
                  />
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Plan
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Next Billing
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredSubscriptions.map((subscription) => (
                <tr key={subscription.subscription_id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <input
                      type="checkbox"
                      className="h-4 w-4 text-blue-600 rounded border-gray-300"
                      checked={selectedSubscriptions.includes(subscription.subscription_id)}
                      onChange={(e) => handleSubscriptionSelect(subscription.subscription_id, e.target.checked)}
                    />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">
                      {subscription.user_name}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {subscription.plan_name}
                      {subscription.is_trial && (
                        <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                          Trial
                        </span>
                      )}
                    </div>
                    {subscription.is_trial && subscription.trial_ends_at && (
                      <div className="text-xs text-gray-500 mt-1">
                        Trial ends: {formatDate(new Date(subscription.trial_ends_at))}
                      </div>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(subscription.status)}`}>
                      {subscription.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {formatCurrency(subscription.amount)}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {formatDate(new Date(subscription.current_period_end))}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    {subscription.is_trial ? (
                      <Button
                        variant="primary"
                        size="sm"
                        className="mr-2"
                        onClick={async () => {
                          if (confirm('Convert this trial to a paid subscription?')) {
                            setProcessingSubscriptionId(subscription.subscription_id);
                            try {
                              await processTrialExpiration(subscription.subscription_id, true);
                              fetchSubscriptions();
                            } catch (error) {
                              console.error('Error converting trial:', error);
                            } finally {
                              setProcessingSubscriptionId(null);
                            }
                          }
                        }}
                        disabled={processingSubscriptionId === subscription.subscription_id}
                      >
                        {processingSubscriptionId === subscription.subscription_id ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Converting...
                          </>
                        ) : (
                          <>
                            <CreditCard className="h-4 w-4 mr-2" />
                            Convert to Paid
                          </>
                        )}
                      </Button>
                    ) : subscription.status === 'active' ? (
                      <Button
                        variant="secondary"
                        size="sm"
                        className="mr-2"
                        onClick={() => {
                          setSelectedSubscription(subscription);
                          setIsUpgradeModalOpen(true);
                        }}
                      >
                        <ArrowUpDown className="h-4 w-4 mr-2" />
                        Change Plan
                      </Button>
                    ) : null}
                    {subscription.status === 'active' ? (
                      <Button
                        variant="secondary"
                        size="sm"
                        className="inline-flex items-center"
                        onClick={async () => {
                          if (confirm('Are you sure you want to cancel this subscription?')) {
                            setProcessingSubscriptionId(subscription.subscription_id);
                            try {
                              await cancelSubscription(subscription.subscription_id, true);
                              fetchSubscriptions();
                            } catch (error) {
                              console.error('Error canceling subscription:', error);
                            } finally {
                              setProcessingSubscriptionId(null);
                            }
                          }
                        }}
                        disabled={isLoading || processingSubscriptionId === subscription.subscription_id}
                      >
                        {processingSubscriptionId === subscription.subscription_id ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Canceling...
                          </>
                        ) : (
                          <>
                            <Trash2 className="h-4 w-4 mr-2" />
                            Cancel
                          </>
                        )}
                      </Button>
                    ) : subscription.status === 'past_due' ? (
                      <Button
                        variant="danger"
                        size="sm"
                        onClick={async () => {
                          try {
                            await retrySubscriptionPayment(subscription.subscription_id);
                            fetchSubscriptions();
                          } catch (error) {
                            console.error('Error retrying payment:', error);
                          }
                        }}
                        className="inline-flex items-center"
                      >
                        <AlertCircle className="h-4 w-4 mr-1" />
                        Retry Payment
                      </Button>
                    ) : (
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={async () => {
                          try {
                            await reactivateSubscription(subscription.subscription_id);
                            fetchSubscriptions();
                          } catch (error) {
                            console.error('Error reactivating subscription:', error);
                          }
                        }}
                        className="inline-flex items-center"
                      >
                        <CreditCard className="h-4 w-4 mr-1" />
                        Reactivate
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <CreateSubscriptionModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onSuccess={fetchSubscriptions}
      />
      
      <UpgradeSubscriptionModal
        subscription={selectedSubscription}
        isOpen={isUpgradeModalOpen}
        onClose={() => {
          setIsUpgradeModalOpen(false);
          setSelectedSubscription(null);
        }}
        onSuccess={fetchSubscriptions}
      />
    </div>
  );
}