-- Stabilize Admin/Supplier authentication and supplier identity synchronization.
-- Keep exactly one auth.users -> profiles trigger.
drop trigger if exists on_signup on auth.users;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.sync_registered_suppliers()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare v_count integer;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin access required';
  end if;

  insert into public.profiles (id,name,role)
  select u.id,
    coalesce(
      nullif(btrim(u.raw_user_meta_data->>'name'),''),
      nullif(btrim(u.raw_user_meta_data->>'full_name'),''),
      split_part(coalesce(u.email,''),'@',1),
      'Supplier'
    ),
    'supplier'
  from auth.users u
  on conflict (id) do update
    set name=coalesce(nullif(excluded.name,''),public.profiles.name),
        role=case when public.profiles.role='admin' then 'admin' else 'supplier' end;

  get diagnostics v_count=row_count;
  return v_count;
end;
$$;

revoke all on function public.sync_registered_suppliers() from public,anon;
grant execute on function public.sync_registered_suppliers() to authenticated;
