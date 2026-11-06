-- Adds the service-report fields used by the second page of an invoice PDF.
-- Run this migration in the Supabase SQL editor before releasing the app build.

alter table public.invoices
  add column if not exists observations text not null default '',
  add column if not exists recommendations text not null default '';
