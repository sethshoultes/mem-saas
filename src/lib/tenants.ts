import { supabase } from './supabase';
import { Tenant } from '../types';

export async function getTenants(): Promise<Tenant[]> {
  const { data, error } = await supabase
    .rpc('get_accessible_tenants');

  if (error) throw error;
  return data || [];
}

export async function createTenant(name: string): Promise<string> {
  const { data, error } = await supabase
    .rpc('create_tenant', { p_name: name });

  if (error) throw error;
  return data;
}

export async function deleteTenant(tenantId: string): Promise<boolean> {
  const { data, error } = await supabase
    .rpc('delete_tenant', { p_tenant_id: tenantId });

  if (error) throw error;
  return data;
}

export async function updateTenant(
  tenantId: string,
  updates: { name?: string; status?: 'active' | 'inactive' }
): Promise<boolean> {
  const { data, error } = await supabase
    .rpc('update_tenant', {
      p_tenant_id: tenantId,
      p_name: updates.name,
      p_status: updates.status
    });

  if (error) throw error;
  return data;
}

export async function getTenantStats(tenantId: string) {
  const { data, error } = await supabase
    .rpc('get_tenant_stats', { p_tenant_id: tenantId });

  if (error) throw error;
  return data;
}