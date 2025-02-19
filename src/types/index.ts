export interface User {
  id: string;
  email: string;
  profile?: {
    full_name: string;
    role: 'admin' | 'tenant_admin' | 'user';
    tenant_id: string | null;
    status: 'active' | 'inactive' | 'suspended';
    created_at: string;
    updated_at: string;
  };
}

export interface UserActivity {
  id: string;
  user_id: string;
  action: string;
  details: Record<string, any>;
  created_at: string;
}

export interface Tenant {
  id: string;
  name: string;
  status: 'active' | 'inactive';
  subscription_status: 'active' | 'canceled' | 'past_due';
  created_at: string;
}

export interface MembershipPlan {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  price: number;
  interval: 'monthly' | 'yearly';
  features: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface MemberSubscription {
  id: string;
  user_id: string;
  plan_id: string;
  status: 'active' | 'canceled' | 'past_due' | 'incomplete';
  current_period_start: string;
  current_period_end: string;
  cancel_at_period_end: boolean;
  stripe_subscription_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface ContentItem {
  id: string;
  tenant_id: string;
  title: string;
  description: string | null;
  content_type: 'html' | 'text' | 'url';
  content: string;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface ContentAccess {
  id: string;
  content_id: string;
  plan_id: string;
  created_at: string;
}

export interface MembershipPlan {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  price: number;
  interval: 'monthly' | 'yearly';
  features: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface MemberSubscription {
  id: string;
  user_id: string;
  plan_id: string;
  status: 'active' | 'canceled' | 'past_due' | 'incomplete';
  current_period_start: string;
  current_period_end: string;
  cancel_at_period_end: boolean;
  stripe_subscription_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface ContentItem {
  id: string;
  tenant_id: string;
  title: string;
  description: string | null;
  content_type: 'html' | 'text' | 'url';
  content: string;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface ContentAccess {
  id: string;
  content_id: string;
  plan_id: string;
  created_at: string;
}

export interface DashboardMetrics {
  total_users: number;
  active_tenants: number;
  monthly_revenue: number;
  active_subscriptions: number;
}