/*
  # Fix content_items foreign key constraint

  1. Changes
    - Drop incorrect foreign key constraint referencing users table
    - Add correct foreign key constraint referencing tenants table
    
  2. Security
    - Maintains data integrity with correct table references
    - No changes to access control
*/

-- Drop the incorrect foreign key constraint
ALTER TABLE content_items
DROP CONSTRAINT IF EXISTS content_items_tenant_id_fkey;

-- Add the correct foreign key constraint
ALTER TABLE content_items
ADD CONSTRAINT content_items_tenant_id_fkey
FOREIGN KEY (tenant_id) REFERENCES tenants(id)
ON DELETE CASCADE;