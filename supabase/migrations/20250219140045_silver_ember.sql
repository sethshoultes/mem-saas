/*
  # Fix membership plans foreign key constraint

  1. Changes
    - Drop incorrect foreign key constraint on membership_plans.tenant_id
    - Add correct foreign key constraint referencing tenants table
    
  2. Reason
    - Current constraint incorrectly references auth.users instead of tenants table
    - This prevents creating membership plans with valid tenant IDs
*/

-- Drop the incorrect foreign key constraint
ALTER TABLE membership_plans
DROP CONSTRAINT IF EXISTS membership_plans_tenant_id_fkey;

-- Add the correct foreign key constraint
ALTER TABLE membership_plans
ADD CONSTRAINT membership_plans_tenant_id_fkey
FOREIGN KEY (tenant_id) REFERENCES tenants(id)
ON DELETE CASCADE;