create extension if not exists pgcrypto;

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 50),
  invite_code text not null unique,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id),
  unique (user_id)
);

create table public.locations (
  id uuid primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  parent_id uuid references public.locations(id),
  sort_order integer not null default 0,
  updated_at timestamptz not null,
  is_deleted boolean not null default false
);

create table public.categories (
  id uuid primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  icon text not null,
  color text not null,
  sort_order integer not null default 0,
  updated_at timestamptz not null,
  is_deleted boolean not null default false
);

create table public.items (
  id uuid primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  location_id uuid not null references public.locations(id),
  category_id uuid references public.categories(id),
  notes text,
  photo_paths text[] not null default '{}',
  created_at timestamptz not null,
  updated_at timestamptz not null,
  is_deleted boolean not null default false
);

create or replace function public.is_family_member(target_family_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where family_id = target_family_id and user_id = auth.uid()
  );
$$;

create or replace function public.create_family(family_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family_id uuid;
  new_invite_code text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if trim(family_name) = '' then raise exception 'Family name is required'; end if;
  if exists (select 1 from public.family_members where user_id = auth.uid()) then
    raise exception 'User already belongs to a family';
  end if;
  new_invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.families(name, invite_code, owner_id)
  values (trim(family_name), new_invite_code, auth.uid()) returning id into new_family_id;
  insert into public.family_members(family_id, user_id, role)
  values (new_family_id, auth.uid(), 'owner');
  return jsonb_build_object('family_id', new_family_id, 'invite_code', new_invite_code);
end;
$$;

create or replace function public.join_family(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if exists (select 1 from public.family_members where user_id = auth.uid()) then
    raise exception 'User already belongs to a family';
  end if;
  select id into target_family_id from public.families
  where invite_code = upper(trim(code));
  if target_family_id is null then raise exception 'Invalid invite code'; end if;
  insert into public.family_members(family_id, user_id)
  values (target_family_id, auth.uid());
  return target_family_id;
end;
$$;

grant execute on function public.create_family(text) to authenticated;
grant execute on function public.join_family(text) to authenticated;

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.locations enable row level security;
alter table public.categories enable row level security;
alter table public.items enable row level security;

create policy "members read families" on public.families for select
using (public.is_family_member(id));
create policy "members read memberships" on public.family_members for select
using (public.is_family_member(family_id));

create policy "members manage locations" on public.locations for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));
create policy "members manage categories" on public.categories for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));
create policy "members manage items" on public.items for all
using (public.is_family_member(family_id))
with check (public.is_family_member(family_id));

insert into storage.buckets (id, name, public)
values ('item-photos', 'item-photos', false)
on conflict (id) do nothing;

create policy "members read item photos" on storage.objects for select
using (
  bucket_id = 'item-photos'
  and public.is_family_member((storage.foldername(name))[1]::uuid)
);
create policy "members upload item photos" on storage.objects for insert
with check (
  bucket_id = 'item-photos'
  and public.is_family_member((storage.foldername(name))[1]::uuid)
);
create policy "members update item photos" on storage.objects for update
using (
  bucket_id = 'item-photos'
  and public.is_family_member((storage.foldername(name))[1]::uuid)
);
create policy "members delete item photos" on storage.objects for delete
using (
  bucket_id = 'item-photos'
  and public.is_family_member((storage.foldername(name))[1]::uuid)
);
