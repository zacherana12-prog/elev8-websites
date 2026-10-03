-- ELEV8 marketplace / escrow foundation
create table if not exists public.marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null unique references public.inventory_items(id) on delete cascade,
  seller_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  category text not null default 'Gaming Items',
  image_url text,
  delivery_type text not null default 'manual' check (delivery_type in ('instant','manual','account','code')),
  delivery_window_minutes integer not null default 30 check (delivery_window_minutes between 1 and 10080),
  is_published boolean not null default false,
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.marketplace_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  buyer_id uuid not null references auth.users(id) on delete restrict,
  listing_id uuid not null references public.marketplace_listings(id) on delete restrict,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  seller_id uuid references public.profiles(id) on delete set null,
  quantity integer not null check (quantity > 0),
  unit_price_usd numeric(14,2) not null check (unit_price_usd >= 0),
  subtotal_usd numeric(14,2) not null check (subtotal_usd >= 0),
  platform_fee_usd numeric(14,2) not null default 0 check (platform_fee_usd >= 0),
  seller_amount_usd numeric(14,2) not null default 0 check (seller_amount_usd >= 0),
  currency text not null default 'USD' check (currency in ('USD','PHP')),
  status text not null default 'awaiting_payment' check (status in ('awaiting_payment','payment_secured','processing','delivered','completed','disputed','cancelled','refunded','partially_refunded')),
  payment_status text not null default 'pending' check (payment_status in ('pending','authorized','paid','failed','refunded','partially_refunded')),
  escrow_status text not null default 'pending' check (escrow_status in ('pending','secured','release_ready','released','disputed','refunded')),
  payment_provider text,
  provider_order_id text,
  payment_reference text,
  buyer_note text,
  seller_note text,
  delivered_at timestamptz,
  buyer_confirmed_at timestamptz,
  auto_release_at timestamptz,
  cancelled_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.marketplace_reservations (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items(id) on delete cascade,
  order_id uuid not null unique references public.marketplace_orders(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  status text not null default 'reserved' check (status in ('reserved','released','consumed')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists marketplace_reservations_active_idx on public.marketplace_reservations(inventory_item_id,status,expires_at);
create table if not exists public.marketplace_delivery_messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.marketplace_orders(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(btrim(body)) between 1 and 8000),
  attachment_url text,
  created_at timestamptz not null default now()
);
create index if not exists marketplace_delivery_messages_order_idx on public.marketplace_delivery_messages(order_id,created_at);
create table if not exists public.marketplace_disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.marketplace_orders(id) on delete cascade,
  opened_by uuid not null references auth.users(id) on delete restrict,
  reason text not null check (char_length(btrim(reason)) between 5 and 3000),
  evidence text,
  status text not null default 'open' check (status in ('open','under_review','released_to_seller','refunded_buyer','partially_resolved','closed')),
  resolution_note text,
  resolved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.marketplace_payment_attempts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.marketplace_orders(id) on delete cascade,
  provider text not null,
  external_id text,
  status text not null default 'created' check (status in ('created','pending','authorized','paid','failed','cancelled','refunded')),
  amount_usd numeric(14,2) not null check (amount_usd >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists marketplace_payment_attempts_order_idx on public.marketplace_payment_attempts(order_id,created_at desc);
create table if not exists public.marketplace_order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.marketplace_orders(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  from_status text,
  to_status text,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists marketplace_order_events_order_idx on public.marketplace_order_events(order_id,created_at desc);
create table if not exists public.marketplace_payment_methods (
  id text primary key,
  label text not null,
  provider text not null,
  enabled boolean not null default false,
  sort_order integer not null default 100,
  note text,
  created_at timestamptz not null default now()
);
insert into public.marketplace_payment_methods(id,label,provider,enabled,sort_order,note) values
('paypal','PayPal','paypal',false,10,'Requires PayPal merchant/marketplace onboarding'),
('apple_pay','Apple Pay','paypal_or_gateway',false,20,'Enabled through a supported payment provider'),
('google_pay','Google Pay','paypal_or_gateway',false,30,'Enabled through a supported payment provider'),
('cards','Visa / Mastercard','gateway',false,40,'Connect a card payment gateway'),
('gcash','GCash','paymongo',false,50,'Connect PayMongo'),
('maya','Maya','paymongo',false,60,'Connect PayMongo'),
('grabpay','GrabPay','paymongo',false,70,'Connect PayMongo'),
('shopeepay','ShopeePay','paymongo',false,80,'Connect PayMongo'),
('qrph','QR Ph','paymongo',false,90,'Connect PayMongo'),
('online_banking','Online Banking','paymongo',false,100,'Connect PayMongo'),
('wise','Wise','wise',false,110,'Use Wise Business transfer/payment-link flow')
on conflict (id) do nothing;

alter table public.marketplace_listings enable row level security;
alter table public.marketplace_orders enable row level security;
alter table public.marketplace_reservations enable row level security;
alter table public.marketplace_delivery_messages enable row level security;
alter table public.marketplace_disputes enable row level security;
alter table public.marketplace_payment_attempts enable row level security;
alter table public.marketplace_order_events enable row level security;
alter table public.marketplace_payment_methods enable row level security;

drop policy if exists marketplace_listings_public_select on public.marketplace_listings;
create policy marketplace_listings_public_select on public.marketplace_listings for select to anon,authenticated using (is_published=true);
drop policy if exists marketplace_listings_admin_all on public.marketplace_listings;
create policy marketplace_listings_admin_all on public.marketplace_listings for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists marketplace_orders_buyer_select on public.marketplace_orders;
drop policy if exists marketplace_orders_participant_select on public.marketplace_orders;
create policy marketplace_orders_participant_select on public.marketplace_orders for select to authenticated using (buyer_id=(select auth.uid()) or seller_id=(select auth.uid()) or public.is_admin());
drop policy if exists marketplace_orders_admin_all on public.marketplace_orders;
create policy marketplace_orders_admin_all on public.marketplace_orders for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists marketplace_delivery_participants_select on public.marketplace_delivery_messages;
create policy marketplace_delivery_participants_select on public.marketplace_delivery_messages for select to authenticated using (exists(select 1 from public.marketplace_orders o where o.id=order_id and (o.buyer_id=(select auth.uid()) or o.seller_id=(select auth.uid()) or public.is_admin())));
drop policy if exists marketplace_delivery_participants_insert on public.marketplace_delivery_messages;
create policy marketplace_delivery_participants_insert on public.marketplace_delivery_messages for insert to authenticated with check (sender_id=(select auth.uid()) and exists(select 1 from public.marketplace_orders o where o.id=order_id and (o.buyer_id=(select auth.uid()) or o.seller_id=(select auth.uid()) or public.is_admin())));
drop policy if exists marketplace_disputes_buyer_select on public.marketplace_disputes;
drop policy if exists marketplace_disputes_participant_select on public.marketplace_disputes;
create policy marketplace_disputes_participant_select on public.marketplace_disputes for select to authenticated using (exists(select 1 from public.marketplace_orders o where o.id=order_id and (o.buyer_id=(select auth.uid()) or o.seller_id=(select auth.uid()) or public.is_admin())));
drop policy if exists marketplace_disputes_buyer_insert on public.marketplace_disputes;
create policy marketplace_disputes_buyer_insert on public.marketplace_disputes for insert to authenticated with check (opened_by=(select auth.uid()) and exists(select 1 from public.marketplace_orders o where o.id=order_id and o.buyer_id=(select auth.uid()) and o.status in ('payment_secured','processing','delivered')));
drop policy if exists marketplace_payment_methods_public_select on public.marketplace_payment_methods;
create policy marketplace_payment_methods_public_select on public.marketplace_payment_methods for select to anon,authenticated using (enabled=true);
drop policy if exists marketplace_payment_methods_admin_all on public.marketplace_payment_methods;
create policy marketplace_payment_methods_admin_all on public.marketplace_payment_methods for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists marketplace_payment_attempts_admin on public.marketplace_payment_attempts;
create policy marketplace_payment_attempts_admin on public.marketplace_payment_attempts for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists marketplace_order_events_admin on public.marketplace_order_events;
create policy marketplace_order_events_admin on public.marketplace_order_events for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists marketplace_reservations_admin on public.marketplace_reservations;
create policy marketplace_reservations_admin on public.marketplace_reservations for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy marketplace_inventory_public_select on public.inventory_items for select to anon using (exists(select 1 from public.marketplace_listings l where l.inventory_item_id=inventory_items.id and l.is_published=true));

create or replace function public.marketplace_available_quantity(p_inventory_item_id uuid)
returns integer language sql security definer set search_path=public as $$
select greatest(0,i.quantity-i.sold_quantity-coalesce((select sum(r.quantity) from public.marketplace_reservations r where r.inventory_item_id=i.id and r.status='reserved' and r.expires_at>now()),0))::integer
from public.inventory_items i
where i.id=p_inventory_item_id and exists(select 1 from public.marketplace_listings l where l.inventory_item_id=i.id and l.is_published=true);
$$;
grant execute on function public.marketplace_available_quantity(uuid) to anon,authenticated;

drop view if exists public.marketplace_public_listings;
create or replace view public.marketplace_public_listings with (security_invoker=true) as
select l.id,l.title,l.description,l.category,l.image_url,l.delivery_type,l.delivery_window_minutes,l.featured,l.created_at,
i.id inventory_item_id,i.name inventory_name,i.ms,i.quantity,i.sold_quantity,
public.marketplace_available_quantity(i.id) available_quantity,i.selling_price_usd price_usd,
coalesce(l.seller_id,i.supplier_id) seller_id
from public.marketplace_listings l join public.inventory_items i on i.id=l.inventory_item_id
where l.is_published=true and i.status not in ('SOLD','CANCELLED / REFUNDED') and i.quantity>i.sold_quantity;
grant select on public.marketplace_public_listings to anon,authenticated;

create or replace function public.create_marketplace_order(p_listing_id uuid,p_quantity integer default 1,p_buyer_note text default null)
returns public.marketplace_orders language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); l public.marketplace_listings%rowtype; i public.inventory_items%rowtype; o public.marketplace_orders%rowtype;
active_reserved integer; available integer; price numeric(14,2); subtotal numeric(14,2); fee numeric(14,2); seller_amount numeric(14,2);
begin
if uid is null then raise exception 'authentication required'; end if;
if p_quantity is null or p_quantity<=0 then raise exception 'quantity must be greater than zero'; end if;
update public.marketplace_reservations set status='released',updated_at=now() where status='reserved' and expires_at<=now();
select * into l from public.marketplace_listings where id=p_listing_id and is_published=true for update;
if not found then raise exception 'listing is not available'; end if;
select * into i from public.inventory_items where id=l.inventory_item_id for update;
if not found then raise exception 'inventory item not found'; end if;
if i.status in ('SOLD','CANCELLED / REFUNDED') then raise exception 'item is unavailable'; end if;
select coalesce(sum(quantity),0) into active_reserved from public.marketplace_reservations where inventory_item_id=i.id and status='reserved' and expires_at>now();
available:=greatest(0,i.quantity-i.sold_quantity-active_reserved);
if p_quantity>available then raise exception 'not enough inventory available'; end if;
price:=round(i.selling_price_usd,2); subtotal:=round(price*p_quantity,2); fee:=round(subtotal*0.10,2); seller_amount:=greatest(0,subtotal-fee);
insert into public.marketplace_orders(order_number,buyer_id,listing_id,inventory_item_id,seller_id,quantity,unit_price_usd,subtotal_usd,platform_fee_usd,seller_amount_usd,buyer_note,auto_release_at,status,payment_status,escrow_status)
values('E8-'||to_char(now(),'YYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,5)),uid,l.id,i.id, p_quantity,price,subtotal,fee,seller_amount,p_buyer_note,now()+interval '24 hours','awaiting_payment','pending','pending')
returning * into o;
insert into public.marketplace_reservations(inventory_item_id,order_id,quantity,expires_at) values(i.id,o.id,p_quantity,now()+interval '20 minutes');
insert into public.marketplace_order_events(order_id,actor_id,event_type,to_status,note) values(o.id,uid,'order_created',o.status,'Stock reserved for 20 minutes pending payment');
return o;
end; $$;
revoke all on function public.create_marketplace_order(uuid,integer,text) from public,anon;
grant execute on function public.create_marketplace_order(uuid,integer,text) to authenticated;

create or replace function public.seller_submit_marketplace_delivery(p_order_id uuid,p_body text,p_attachment_url text default null)
returns public.marketplace_delivery_messages language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); o public.marketplace_orders%rowtype; d public.marketplace_delivery_messages%rowtype;
begin
if uid is null then raise exception 'authentication required'; end if;
select * into o from public.marketplace_orders where id=p_order_id for update;
if not found then raise exception 'order not found'; end if;
if o.seller_id is distinct from uid and not public.is_admin() then raise exception 'seller access required'; end if;
if o.status not in ('payment_secured','processing') or o.payment_status<>'paid' then raise exception 'order is not ready for delivery'; end if;
insert into public.marketplace_delivery_messages(order_id,sender_id,body,attachment_url) values(o.id,uid,p_body,p_attachment_url) returning * into d;
update public.marketplace_orders set status='delivered',delivered_at=now(),updated_at=now() where id=o.id;
insert into public.marketplace_order_events(order_id,actor_id,event_type,from_status,to_status,note) values(o.id,uid,'seller_delivered','payment_secured','delivered','Seller submitted delivery');
return d;
end; $$;
revoke all on function public.seller_submit_marketplace_delivery(uuid,text,text) from public,anon;
grant execute on function public.seller_submit_marketplace_delivery(uuid,text,text) to authenticated;

create or replace function public.confirm_marketplace_order(p_order_id uuid)
returns public.marketplace_orders language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); o public.marketplace_orders%rowtype; i public.inventory_items%rowtype; s public.supplier_stock_items%rowtype; rate numeric(14,2);
begin
if uid is null then raise exception 'authentication required'; end if;
select * into o from public.marketplace_orders where id=p_order_id for update;
if not found then raise exception 'order not found'; end if;
if o.buyer_id is distinct from uid and not public.is_admin() then raise exception 'buyer access required'; end if;
if o.status<>'delivered' or o.payment_status<>'paid' then raise exception 'order is not ready to complete'; end if;
select * into i from public.inventory_items where id=o.inventory_item_id for update;
if not found then raise exception 'inventory item not found'; end if;
if i.quantity-i.sold_quantity<o.quantity then raise exception 'inventory balance is inconsistent'; end if;
insert into public.inventory_sales(inventory_item_id,quantity,unit_price_usd,note,created_by) values(i.id,o.quantity,o.unit_price_usd,'Marketplace order '||o.order_number,uid);
update public.inventory_items set sold_quantity=sold_quantity+o.quantity,status=case when sold_quantity+o.quantity>=quantity then 'SOLD' else 'PARTIALLY SOLD' end,updated_at=now() where id=i.id;
if i.supplier_stock_id is not null then
select * into s from public.supplier_stock_items where id=i.supplier_stock_id for update;
if found then
update public.supplier_stock_items set sold_quantity=sold_quantity+o.quantity,status=case when sold_quantity+o.quantity>=collected_quantity then 'sold' when sold_quantity+o.quantity>0 then 'partially_sold' else status end,last_sold_at=now(),updated_at=now() where id=s.id;
end if; end if;
update public.marketplace_reservations set status='consumed',updated_at=now() where order_id=o.id and status='reserved';
update public.marketplace_orders set status='completed',escrow_status='release_ready',buyer_confirmed_at=now(),updated_at=now() where id=o.id returning * into o;
if o.seller_id is not null and not exists(select 1 from public.supplier_earnings_ledger where source_type='manual_entry' and source_id=o.id) then
rate:=case when o.quantity>0 then round(o.seller_amount_usd/o.quantity,2) else 0 end;
insert into public.supplier_earnings_ledger(supplier_id,item_name,quantity,rate,total,status,source_type,source_id,source_note,metadata)
values(o.seller_id,i.name,o.quantity,rate,o.seller_amount_usd,'completed','manual_entry',o.id,'Marketplace escrow completion • '||o.order_number,jsonb_build_object('marketplace_order_id',o.id,'buyer_id',o.buyer_id,'platform_fee_usd',o.platform_fee_usd));
end if;
insert into public.marketplace_order_events(order_id,actor_id,event_type,from_status,to_status,note) values(o.id,uid,'buyer_confirmed','delivered','completed','Buyer confirmed receipt; seller earnings marked completed');
return o;
end; $$;
revoke all on function public.confirm_marketplace_order(uuid) from public,anon;
grant execute on function public.confirm_marketplace_order(uuid) to authenticated;

create or replace function public.open_marketplace_dispute(p_order_id uuid,p_reason text,p_evidence text default null)
returns public.marketplace_disputes language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); o public.marketplace_orders%rowtype; d public.marketplace_disputes%rowtype;
begin
if uid is null then raise exception 'authentication required'; end if;
select * into o from public.marketplace_orders where id=p_order_id for update;
if not found then raise exception 'order not found'; end if;
if o.buyer_id is distinct from uid then raise exception 'buyer access required'; end if;
if o.status not in ('payment_secured','processing','delivered') then raise exception 'order cannot be disputed'; end if;
if exists(select 1 from public.marketplace_disputes where order_id=o.id) then raise exception 'dispute already exists'; end if;
insert into public.marketplace_disputes(order_id,opened_by,reason,evidence) values(o.id,uid,p_reason,p_evidence) returning * into d;
update public.marketplace_orders set status='disputed',escrow_status='disputed',updated_at=now() where id=o.id;
insert into public.marketplace_order_events(order_id,actor_id,event_type,from_status,to_status,note) values(o.id,uid,'dispute_opened',o.status,'disputed',p_reason);
return d;
end; $$;
revoke all on function public.open_marketplace_dispute(uuid,text,text) from public,anon;
grant execute on function public.open_marketplace_dispute(uuid,text,text) to authenticated;

create or replace function public.cancel_marketplace_order(p_order_id uuid)
returns public.marketplace_orders language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); o public.marketplace_orders%rowtype;
begin
if uid is null then raise exception 'authentication required'; end if;
select * into o from public.marketplace_orders where id=p_order_id for update;
if not found then raise exception 'order not found'; end if;
if o.buyer_id is distinct from uid and not public.is_admin() then raise exception 'access denied'; end if;
if o.status<>'awaiting_payment' or o.payment_status not in ('pending','failed') then raise exception 'order cannot be cancelled'; end if;
update public.marketplace_reservations set status='released',updated_at=now() where order_id=o.id and status='reserved';
update public.marketplace_orders set status='cancelled',escrow_status='refunded',cancelled_at=now(),updated_at=now() where id=o.id returning * into o;
insert into public.marketplace_order_events(order_id,actor_id,event_type,from_status,to_status,note) values(o.id,uid,'order_cancelled','awaiting_payment','cancelled','Payment was not secured; inventory reservation released');
return o;
end; $$;
revoke all on function public.cancel_marketplace_order(uuid) from public,anon;
grant execute on function public.cancel_marketplace_order(uuid) to authenticated;
