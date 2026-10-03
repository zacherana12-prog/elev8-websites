-- ELEV8 marketplace buyer profiles and seller verification
create table if not exists public.marketplace_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ELEV8 User',
  bio text,
  avatar_url text,
  buyer_enabled boolean not null default true,
  seller_status text not null default 'not_applied' check (seller_status in ('not_applied','pending','approved','denied','suspended')),
  seller_verified_at timestamptz,
  seller_review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.seller_verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  legal_name text not null,
  country text not null,
  contact_method text not null,
  contact_value text not null,
  seller_type text not null default 'individual' check (seller_type in ('individual','business')),
  gaming_platforms text,
  inventory_categories text,
  experience text,
  application_note text,
  status text not null default 'pending' check (status in ('pending','approved','denied','withdrawn')),
  admin_note text,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists seller_verification_one_pending_per_user on public.seller_verification_requests(user_id) where status='pending';
alter table public.marketplace_profiles enable row level security;
alter table public.seller_verification_requests enable row level security;
create table if not exists public.marketplace_public_seller_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ELEV8 Seller',
  bio text,
  avatar_url text,
  seller_verified_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.marketplace_public_seller_profiles enable row level security;
