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


create or replace function public.sync_marketplace_public_seller_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.seller_status = 'approved' then
    insert into public.marketplace_public_seller_profiles
      (user_id, display_name, bio, avatar_url, seller_verified_at, updated_at)
    values
      (new.user_id, coalesce(nullif(new.display_name,''),'ELEV8 Seller'), new.bio, new.avatar_url, new.seller_verified_at, now())
    on conflict (user_id) do update set
      display_name = excluded.display_name,
      bio = excluded.bio,
      avatar_url = excluded.avatar_url,
      seller_verified_at = excluded.seller_verified_at,
      updated_at = now();
  else
    delete from public.marketplace_public_seller_profiles where user_id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_marketplace_public_seller_profile on public.marketplace_profiles;
create trigger trg_sync_marketplace_public_seller_profile
after insert or update of display_name, bio, avatar_url, seller_status, seller_verified_at
on public.marketplace_profiles
for each row execute function public.sync_marketplace_public_seller_profile();

create or replace function public.review_seller_verification(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
)
returns public.seller_verification_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  r public.seller_verification_requests;
begin
  if me is null or not public.is_admin() then raise exception 'Admin access required.'; end if;
  if p_status not in ('approved','denied') then raise exception 'Invalid seller verification status.'; end if;

  select * into r from public.seller_verification_requests where id=p_request_id for update;
  if not found then raise exception 'Seller verification request not found.'; end if;
  if r.status <> 'pending' then raise exception 'Only pending applications can be reviewed.'; end if;

  update public.seller_verification_requests
  set status=p_status,
      admin_note=nullif(trim(coalesce(p_admin_note,'')),''),
      reviewed_by=me,
      reviewed_at=now(),
      updated_at=now()
  where id=r.id
  returning * into r;

  insert into public.marketplace_profiles
    (user_id,display_name,seller_status,seller_verified_at,seller_review_note,updated_at)
  values
    (r.user_id,coalesce(nullif(r.display_name,''),'ELEV8 User'),p_status,
     case when p_status='approved' then now() else null end,r.admin_note,now())
  on conflict (user_id) do update set
    display_name=excluded.display_name,
    seller_status=excluded.seller_status,
    seller_verified_at=excluded.seller_verified_at,
    seller_review_note=excluded.seller_review_note,
    updated_at=now();

  return r;
end;
$$;

revoke all on function public.review_seller_verification(uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_seller_verification(uuid,text,text) to authenticated;
revoke all on function public.sync_marketplace_public_seller_profile() from public,anon,authenticated;
