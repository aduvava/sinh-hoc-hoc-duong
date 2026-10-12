-- Eco-Bio Panel MVP schema. Review in a development project before running.
-- All exposed tables use RLS. Public keys never bypass these policies.

create extension if not exists pgcrypto;

create or replace function public.has_project_role()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'operator'), false);
$$;

create or replace function public.is_project_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  dimensions text,
  status text not null default 'research' check (status in ('research','pilot','available')),
  expected_price_vnd numeric(12,2),
  image_path text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.partner_applications (
  id uuid primary key default gen_random_uuid(),
  contact_name text not null check (length(contact_name) between 1 and 120),
  email text not null check (length(email) <= 180),
  phone text check (phone is null or length(phone) <= 24),
  partner_type text not null check (partner_type in ('salon','farmer','cooperative','other')),
  material_types text[] not null default '{}',
  estimated_kg numeric(12,2) check (estimated_kg is null or estimated_kg >= 0),
  address_text text,
  consent boolean not null default false check (consent),
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.customer_inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 120),
  contact_info text not null check (length(contact_info) <= 180),
  email text check (email is null or length(email) <= 180),
  phone text check (phone is null or length(phone) <= 24),
  quantity integer not null default 1 check (quantity between 1 and 99),
  inquiry_type text not null default 'sample_interest' check (inquiry_type in ('sample_interest','product_question','other')),
  consent boolean not null default false check (consent),
  status text not null default 'new' check (status in ('new','contacted','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.material_collections (
  id uuid primary key default gen_random_uuid(),
  material_type text not null check (material_type in ('straw','hair')),
  amount_kg numeric(12,2) not null check (amount_kg > 0),
  collection_date date not null,
  supplier_name text,
  supplier_contact text,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected')),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.production_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique check (length(batch_code) between 3 and 60),
  product_id uuid references public.products(id) on delete set null,
  production_date date,
  panels_count integer not null default 0 check (panels_count >= 0),
  straw_used_kg numeric(12,2) not null default 0 check (straw_used_kg >= 0),
  hair_used_kg numeric(12,2) not null default 0 check (hair_used_kg >= 0),
  status text not null default 'draft' check (status in ('draft','confirmed')),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_passports (
  id uuid primary key default gen_random_uuid(),
  passport_code text not null unique check (length(passport_code) between 3 and 60),
  product_id uuid references public.products(id) on delete set null,
  batch_id uuid references public.production_batches(id) on delete set null,
  material_summary text not null,
  usage_notes text,
  status text not null default 'draft' check (status in ('draft','published')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.lab_tests (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid references public.product_passports(id) on delete set null,
  test_type text not null check (test_type in ('acoustic','durability','humidity','fire_safety','other')),
  sample_code text not null,
  test_date date not null,
  result_summary text not null,
  method text,
  control_sample text,
  result_data jsonb not null default '{}'::jsonb,
  evidence_path text,
  status text not null default 'preliminary' check (status in ('preliminary','verified')),
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists material_collections_impact_idx on public.material_collections (material_type, status, is_public);
create index if not exists production_batches_impact_idx on public.production_batches (status, is_public);
create index if not exists lab_tests_public_idx on public.lab_tests (is_public, test_date desc);
create index if not exists partner_applications_verified_idx on public.partner_applications (status, is_public);
create index if not exists product_passports_code_idx on public.product_passports (passport_code, status);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products for each row execute function public.set_updated_at();
drop trigger if exists material_collections_set_updated_at on public.material_collections;
create trigger material_collections_set_updated_at before update on public.material_collections for each row execute function public.set_updated_at();
drop trigger if exists production_batches_set_updated_at on public.production_batches;
create trigger production_batches_set_updated_at before update on public.production_batches for each row execute function public.set_updated_at();
drop trigger if exists product_passports_set_updated_at on public.product_passports;
create trigger product_passports_set_updated_at before update on public.product_passports for each row execute function public.set_updated_at();

grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant select (material_type, amount_kg, status, is_public) on public.material_collections to anon, authenticated;
grant select (batch_code, production_date, panels_count, status, is_public) on public.production_batches to anon, authenticated;
grant select (status, is_public) on public.partner_applications to anon, authenticated;
grant select on public.product_passports to anon, authenticated;
grant select on public.lab_tests to anon, authenticated;
grant insert (contact_name, email, phone, partner_type, material_types, estimated_kg, address_text, consent) on public.partner_applications to anon, authenticated;
grant insert (name, contact_info, email, phone, quantity, inquiry_type, consent) on public.customer_inquiries to anon, authenticated;
grant select, insert, update, delete on public.products, public.partner_applications, public.customer_inquiries,
  public.material_collections, public.production_batches, public.product_passports, public.lab_tests to authenticated;

alter table public.products enable row level security;
alter table public.partner_applications enable row level security;
alter table public.customer_inquiries enable row level security;
alter table public.material_collections enable row level security;
alter table public.production_batches enable row level security;
alter table public.product_passports enable row level security;
alter table public.lab_tests enable row level security;

drop policy if exists "Public active products" on public.products;
create policy "Public active products" on public.products for select to anon, authenticated using (is_active = true);
drop policy if exists "Project roles manage products" on public.products;
drop policy if exists "Project roles read products" on public.products;
create policy "Project roles read products" on public.products for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert products" on public.products;
create policy "Project roles insert products" on public.products for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update products" on public.products;
create policy "Project roles update products" on public.products for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete products" on public.products;
create policy "Project admins delete products" on public.products for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Visitors submit partner applications" on public.partner_applications;
create policy "Visitors submit partner applications" on public.partner_applications for insert to anon, authenticated with check (consent = true and status = 'pending' and is_public = false);
drop policy if exists "Public partner count rows" on public.partner_applications;
create policy "Public partner count rows" on public.partner_applications for select to anon, authenticated using (status = 'verified' and is_public = true);
drop policy if exists "Project roles manage partner applications" on public.partner_applications;
drop policy if exists "Project roles read partner applications" on public.partner_applications;
create policy "Project roles read partner applications" on public.partner_applications for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert partner applications" on public.partner_applications;
create policy "Project roles insert partner applications" on public.partner_applications for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update partner applications" on public.partner_applications;
create policy "Project roles update partner applications" on public.partner_applications for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete partner applications" on public.partner_applications;
create policy "Project admins delete partner applications" on public.partner_applications for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Visitors submit customer inquiries" on public.customer_inquiries;
create policy "Visitors submit customer inquiries" on public.customer_inquiries for insert to anon, authenticated with check (consent = true and status = 'new');
drop policy if exists "Project roles manage customer inquiries" on public.customer_inquiries;
drop policy if exists "Project roles read customer inquiries" on public.customer_inquiries;
create policy "Project roles read customer inquiries" on public.customer_inquiries for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert customer inquiries" on public.customer_inquiries;
create policy "Project roles insert customer inquiries" on public.customer_inquiries for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update customer inquiries" on public.customer_inquiries;
create policy "Project roles update customer inquiries" on public.customer_inquiries for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete customer inquiries" on public.customer_inquiries;
create policy "Project admins delete customer inquiries" on public.customer_inquiries for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Public confirmed material totals" on public.material_collections;
create policy "Public confirmed material totals" on public.material_collections for select to anon, authenticated using (status = 'confirmed' and is_public = true);
drop policy if exists "Project roles manage collections" on public.material_collections;
drop policy if exists "Project roles read collections" on public.material_collections;
create policy "Project roles read collections" on public.material_collections for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert collections" on public.material_collections;
create policy "Project roles insert collections" on public.material_collections for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update collections" on public.material_collections;
create policy "Project roles update collections" on public.material_collections for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete collections" on public.material_collections;
create policy "Project admins delete collections" on public.material_collections for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Public confirmed batch totals" on public.production_batches;
create policy "Public confirmed batch totals" on public.production_batches for select to anon, authenticated using (status = 'confirmed' and is_public = true);
drop policy if exists "Project roles manage batches" on public.production_batches;
drop policy if exists "Project roles read batches" on public.production_batches;
create policy "Project roles read batches" on public.production_batches for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert batches" on public.production_batches;
create policy "Project roles insert batches" on public.production_batches for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update batches" on public.production_batches;
create policy "Project roles update batches" on public.production_batches for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete batches" on public.production_batches;
create policy "Project admins delete batches" on public.production_batches for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Public published passports" on public.product_passports;
create policy "Public published passports" on public.product_passports for select to anon, authenticated using (status = 'published');
drop policy if exists "Project roles manage passports" on public.product_passports;
drop policy if exists "Project roles read passports" on public.product_passports;
create policy "Project roles read passports" on public.product_passports for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert passports" on public.product_passports;
create policy "Project roles insert passports" on public.product_passports for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update passports" on public.product_passports;
create policy "Project roles update passports" on public.product_passports for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete passports" on public.product_passports;
create policy "Project admins delete passports" on public.product_passports for delete to authenticated using ((select public.is_project_admin()));

drop policy if exists "Public published lab results" on public.lab_tests;
create policy "Public published lab results" on public.lab_tests for select to anon, authenticated using (is_public = true);
drop policy if exists "Project roles manage lab tests" on public.lab_tests;
drop policy if exists "Project roles read lab tests" on public.lab_tests;
create policy "Project roles read lab tests" on public.lab_tests for select to authenticated using ((select public.has_project_role()));
drop policy if exists "Project roles insert lab tests" on public.lab_tests;
create policy "Project roles insert lab tests" on public.lab_tests for insert to authenticated with check ((select public.has_project_role()));
drop policy if exists "Project roles update lab tests" on public.lab_tests;
create policy "Project roles update lab tests" on public.lab_tests for update to authenticated using ((select public.has_project_role())) with check ((select public.has_project_role()));
drop policy if exists "Project admins delete lab tests" on public.lab_tests;
create policy "Project admins delete lab tests" on public.lab_tests for delete to authenticated using ((select public.is_project_admin()));

create or replace function public.get_eco_impact()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'straw_kg', (select sum(amount_kg) from public.material_collections where material_type = 'straw' and status = 'confirmed' and is_public = true),
    'hair_kg', (select sum(amount_kg) from public.material_collections where material_type = 'hair' and status = 'confirmed' and is_public = true),
    'panels', (select sum(panels_count) from public.production_batches where status = 'confirmed' and is_public = true),
    'partners', (select count(*) from public.partner_applications where status = 'verified' and is_public = true having count(*) > 0)
  );
$$;
grant execute on function public.get_eco_impact() to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('eco-public', 'eco-public', true, 15728640, array['image/jpeg','image/png','image/webp','application/pdf','video/mp4'])
on conflict (id) do nothing;

drop policy if exists "Read public Eco evidence" on storage.objects;
create policy "Read public Eco evidence" on storage.objects for select to anon, authenticated using (bucket_id = 'eco-public');
drop policy if exists "Project roles upload Eco evidence" on storage.objects;
create policy "Project roles upload Eco evidence" on storage.objects for insert to authenticated with check (bucket_id = 'eco-public' and (select public.has_project_role()));
drop policy if exists "Project roles update Eco evidence" on storage.objects;
create policy "Project roles update Eco evidence" on storage.objects for update to authenticated using (bucket_id = 'eco-public' and (select public.has_project_role())) with check (bucket_id = 'eco-public' and (select public.has_project_role()));
drop policy if exists "Project roles delete Eco evidence" on storage.objects;
create policy "Project roles delete Eco evidence" on storage.objects for delete to authenticated using (bucket_id = 'eco-public' and (select public.is_project_admin()));

