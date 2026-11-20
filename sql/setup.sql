-- Run in Supabase SQL Editor for a NEW project. Never expose service_role keys.
create extension if not exists pgcrypto;
create table if not exists public.products (id uuid primary key default gen_random_uuid(),name text not null,category text not null,price numeric(10,2) not null check(price>=0),weight text not null default 'Pack',description text not null default '',image_url text,stock integer not null default 0 check(stock>=0),active boolean not null default true,featured boolean not null default false,created_at timestamptz not null default now());
create table if not exists public.orders (id uuid primary key default gen_random_uuid(),customer_name text not null,phone text not null,address text not null,items jsonb not null,total numeric(10,2) not null,status text not null default 'New',created_at timestamptz not null default now());
create table if not exists public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.admins enable row level security;
create policy "Admins can read own membership" on public.admins for select to authenticated using (user_id=(select auth.uid()));
create policy "Public view active products" on public.products for select to anon,authenticated using (active or exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Admin insert products" on public.products for insert to authenticated with check(exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Admin update products" on public.products for update to authenticated using(exists(select 1 from public.admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Admin delete products" on public.products for delete to authenticated using(exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Admin read orders" on public.orders for select to authenticated using(exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Admin update orders" on public.orders for update to authenticated using(exists(select 1 from public.admins where user_id=(select auth.uid()))) with check(exists(select 1 from public.admins where user_id=(select auth.uid())));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('product-images','product-images',true,5000000,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy "Admins upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images' and exists(select 1 from public.admins where user_id=(select auth.uid())));
create policy "Public read product images" on storage.objects for select to anon,authenticated using(bucket_id='product-images');
-- Orders are created ONLY by this server-side database function. Prices are calculated from the products table.
create or replace function public.place_order(p_name text,p_phone text,p_address text,p_items jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare entry jsonb; prod record; quantity integer; order_items jsonb:='[]'::jsonb; total_amount numeric:=0; order_id uuid; item_count integer:=0;
begin
 if length(trim(p_name)) not between 1 and 100 or p_phone !~ '^[0-9]{10}$' or length(trim(p_address)) not between 5 and 500 then raise exception 'Invalid customer details'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'Invalid cart'; end if;
 for entry in select value from jsonb_array_elements(p_items) loop
  if (entry->>'qty') !~ '^[0-9]+$' then raise exception 'Invalid quantity'; end if;
  quantity:=(entry->>'qty')::integer;
  if quantity not between 1 and 50 then raise exception 'Invalid quantity'; end if;
  select id,name,price,stock into prod from public.products where id=(entry->>'id')::uuid and active=true and price>0;
  if not found or prod.stock<quantity then raise exception 'Product unavailable or insufficient stock'; end if;
  order_items:=order_items||jsonb_build_array(jsonb_build_object('id',prod.id,'name',prod.name,'price',prod.price,'qty',quantity));
  total_amount:=total_amount+prod.price*quantity;
  item_count:=item_count+1;
 end loop;
 if item_count=0 then raise exception 'Empty cart'; end if;
 insert into public.orders(customer_name,phone,address,items,total) values(trim(p_name),p_phone,trim(p_address),order_items,total_amount) returning id into order_id;
 return jsonb_build_object('id',order_id,'items',order_items,'total',total_amount);
end $$;
revoke all on function public.place_order(text,text,text,jsonb) from public;
grant execute on function public.place_order(text,text,text,jsonb) to anon,authenticated;
-- IMPORTANT: create an admin user in Supabase Authentication, then add their UUID:
-- insert into public.admins(user_id) values ('REPLACE_WITH_ADMIN_AUTH_USER_UUID');
-- Disable public sign-ups in Supabase Auth settings and configure rate limits/CAPTCHA before public launch.
