-- LEO Hotel ordering system
-- Safe to run repeatedly. Existing tables, rows, policies, and realtime entries are preserved.
-- Supabase project: LEO-Hotel
-- Region: ap-south-1

create extension if not exists pgcrypto;

create table if not exists public.restaurant_tables (
  id uuid primary key default gen_random_uuid(),
  table_number integer not null unique check (table_number between 1 and 5),
  table_name text not null,
  public_code text not null unique,
  qr_token uuid not null unique default gen_random_uuid(),
  is_active boolean not null default true,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  sort_order integer not null default 0
);

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.menu_categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text not null default '',
  price numeric(10,2) not null check (price >= 0),
  image_url text,
  rating numeric(2,1) not null default 4.5 check (rating between 0 and 5),
  prep_minutes integer not null default 15 check (prep_minutes > 0),
  tags text[] not null default '{}',
  dietary text[] not null default '{}',
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  table_id uuid references public.restaurant_tables(id) on delete set null,
  customer_name text,
  customer_phone text,
  order_type text not null default 'dine_in' check (order_type in ('dine_in','takeaway','delivery')),
  status text not null default 'received' check (status in ('received','confirmed','preparing','ready','served','completed','cancelled')),
  payment_method text not null default 'pay_later' check (payment_method in ('online_demo','cash','upi_demo','pay_later')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  subtotal numeric(10,2) not null default 0 check (subtotal >= 0),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete restrict,
  item_name text not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(10,2) generated always as (unit_price * quantity) stored
);

create table if not exists public.waiter_calls (
  id uuid primary key default gen_random_uuid(),
  table_id uuid references public.restaurant_tables(id) on delete set null,
  message text not null default 'Guest needs assistance',
  status text not null default 'open' check (status in ('open','acknowledged','resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('admin','waiter','kitchen')),
  created_at timestamptz not null default now()
);

create index if not exists orders_status_created_idx on public.orders(status, created_at desc);
create index if not exists orders_table_idx on public.orders(table_id);
create index if not exists waiter_calls_status_idx on public.waiter_calls(status, created_at desc);
create index if not exists order_items_order_idx on public.order_items(order_id);

insert into public.restaurant_tables (table_number, table_name, public_code) values
  (1, 'Window table', 'LEO-T1-7K4P'),
  (2, 'Garden table', 'LEO-T2-9Q2M'),
  (3, 'Library table', 'LEO-T3-4N8R'),
  (4, 'Corner table', 'LEO-T4-6X1B'),
  (5, 'Bar table', 'LEO-T5-3D7H')
on conflict (table_number) do nothing;

insert into public.menu_categories (name, slug, sort_order) values
  ('Coffee & tea', 'coffee-tea', 1),
  ('All-day bites', 'all-day-bites', 2),
  ('Indian table', 'indian-table', 3),
  ('Sweet things', 'sweet-things', 4)
on conflict (slug) do nothing;

insert into public.menu_items (category_id, name, slug, description, price, image_url, rating, prep_minutes, tags, dietary)
select c.id, x.name, x.slug, x.description, x.price, x.image_url, x.rating, x.prep_minutes, x.tags, x.dietary
from public.menu_categories c
join (values
  ('coffee-tea','Flat White','flat-white','Double espresso, silky microfoam',160,'https://images.unsplash.com/photo-1570968915860-54d5c301fa9f?auto=format&fit=crop&w=900&q=85',4.9,8,array['Most ordered'],array['vegetarian']),
  ('coffee-tea','Masala Chai','masala-chai','Black tea, ginger, cardamom, warm milk',120,'https://images.unsplash.com/photo-1571934811356-5cc061b6821f?auto=format&fit=crop&w=900&q=85',4.8,8,array['Comfort'],array['vegetarian']),
  ('all-day-bites','Mushroom Toast','mushroom-toast','Sourdough, whipped ricotta, herbs',320,'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?auto=format&fit=crop&w=900&q=85',4.7,14,array['Leo favourite'],array['vegetarian']),
  ('all-day-bites','Samosa Plate','samosa-plate','Three crisp pastries, tamarind, mint',170,'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=900&q=85',4.6,12,array['Shareable'],array['vegetarian']),
  ('indian-table','Chicken Biryani','chicken-biryani','Fragrant basmati, saffron, slow-cooked chicken',390,'https://images.unsplash.com/photo-1563379091339-03246963d96c?auto=format&fit=crop&w=900&q=85',4.9,22,array['Most ordered','Chef pick'],array['halal']),
  ('indian-table','Paneer Tikka','paneer-tikka','Charred paneer, peppers, mint chutney',280,'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=900&q=85',4.8,18,array['New'],array['vegetarian']),
  ('sweet-things','Lemon Olive Cake','lemon-olive-cake','Bright, tender, a little bit lovely',190,'https://images.unsplash.com/photo-1519915028121-7d3463d20b13?auto=format&fit=crop&w=900&q=85',4.7,5,array['Baked today'],array['vegetarian']),
  ('sweet-things','Banana Bread','banana-bread','Toasted walnuts, cultured butter',180,'https://images.unsplash.com/photo-1606101273945-e9eba91c0c0d?auto=format&fit=crop&w=900&q=80',4.6,5,array['Most ordered'],array['vegetarian'])
) as x(category_slug,name,slug,description,price,image_url,rating,prep_minutes,tags,dietary) on x.category_slug = c.slug
on conflict (slug) do nothing;

alter table public.restaurant_tables enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.waiter_calls enable row level security;
alter table public.staff_profiles enable row level security;

drop policy if exists "public can view active tables" on public.restaurant_tables;
drop policy if exists "public can view menu categories" on public.menu_categories;
drop policy if exists "public can view available menu" on public.menu_items;
drop policy if exists "guests can create orders" on public.orders;
drop policy if exists "guests can add order items" on public.order_items;
drop policy if exists "guests can call waiter" on public.waiter_calls;
drop policy if exists "staff can view profiles" on public.staff_profiles;
drop policy if exists "staff can manage orders" on public.orders;
drop policy if exists "staff can manage order items" on public.order_items;
drop policy if exists "staff can manage waiter calls" on public.waiter_calls;

create policy "public can view active tables" on public.restaurant_tables for select to anon, authenticated using (is_active = true);
create policy "public can view menu categories" on public.menu_categories for select to anon, authenticated using (true);
create policy "public can view available menu" on public.menu_items for select to anon, authenticated using (is_available = true);
create policy "guests can create orders" on public.orders for insert to anon, authenticated with check (status = 'received' and payment_status = 'pending');
create policy "guests can add order items" on public.order_items for insert to anon, authenticated with check (exists (select 1 from public.orders o where o.id = order_id and o.status = 'received'));
create policy "guests can call waiter" on public.waiter_calls for insert to anon, authenticated with check (status = 'open');
create policy "staff can view profiles" on public.staff_profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy "staff can manage orders" on public.orders for all to authenticated using (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid()))) with check (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid())));
create policy "staff can manage order items" on public.order_items for all to authenticated using (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid()))) with check (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid())));
create policy "staff can manage waiter calls" on public.waiter_calls for all to authenticated using (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid()))) with check (exists (select 1 from public.staff_profiles p where p.user_id = (select auth.uid())));

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders') then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'waiter_calls') then
    alter publication supabase_realtime add table public.waiter_calls;
  end if;
end $$;
