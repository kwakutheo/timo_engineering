-- Adds the technician and representative sign-off fields to the invoices table.
-- Run this migration in the Supabase SQL editor.

alter table public.invoices
  add column if not exists technician_name text not null default '',
  add column if not exists representative_name text not null default '';

