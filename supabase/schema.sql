-- =====================================================================
-- DÉPANINI — schéma Supabase / PostgreSQL + PostGIS
-- Exécuter dans l'éditeur SQL de Supabase (ou `supabase db reset`).
-- =====================================================================

create extension if not exists postgis;

-- ---------- Types ----------
create type user_role       as enum ('client', 'provider', 'admin');
create type service_axis    as enum ('depannage', 'ambulance');
create type provider_status as enum ('pending', 'verified', 'rejected', 'suspended');
create type request_status  as enum ('sent', 'accepted', 'en_route', 'on_site', 'done', 'cancelled', 'expired');
create type payment_status  as enum ('submitted', 'validated', 'rejected');
create type ad_surface      as enum ('client', 'pro');

-- ---------- Catégories (extensibles : V2 = soins, pneus, plombier…) ----------
create table categories (
  id          text primary key,             -- 'remorquage', 'ambulance_allonge'…
  axis        service_axis not null,
  label_fr    text not null,
  label_ar    text not null,
  sort_order  int  not null default 0
);

insert into categories (id, axis, label_fr, label_ar, sort_order) values
  ('remorquage',        'depannage', 'Remorquage',                 'سحب السيارات',        1),
  ('depannage_place',   'depannage', 'Dépannage sur place',        'تصليح في المكان',     2),
  ('mecanicien',        'depannage', 'Mécanicien mobile',          'ميكانيكي متنقل',      3),
  ('ouverture',         'depannage', 'Ouverture de véhicule',      'فتح السيارة',         4),
  ('ambulance_allonge', 'ambulance', 'Transport allongé',          'نقل ممدد',            1),
  ('ambulance_assis',   'ambulance', 'Transport assis',            'نقل جالس',            2),
  ('ambulance_oxygene', 'ambulance', 'Ambulance avec oxygène',     'إسعاف بالأكسجين',     3);

-- ---------- Profils ----------
create table profiles (
  id          uuid primary key references auth.users on delete cascade,
  role        user_role not null default 'client',
  full_name   text,
  phone       text,
  language    text not null default 'fr' check (language in ('fr','ar')),
  created_at  timestamptz not null default now()
);

-- ---------- Prestataires ----------
create table providers (
  id                  uuid primary key references profiles(id) on delete cascade,
  business_name       text not null,
  axis                service_axis not null,
  categories          text[] not null default '{}',
  wilaya              text not null,
  radius_km           int  not null default 20 check (radius_km between 1 and 300),
  location            geography(point, 4326),
  is_online           boolean not null default false,
  status              provider_status not null default 'pending',
  subscription_until  date,                         -- abonnement 1 500 DA/mois
  base_price_da       int,                          -- tarif indicatif, défini par le prestataire
  price_per_km_da     int,
  vehicle_desc        text,                         -- 'Plateau 5 t', 'Ambulance équipée'
  plate               text,
  rating_avg          numeric(2,1) not null default 0,
  rating_count        int not null default 0,
  updated_at          timestamptz not null default now()
);
create index providers_location_gix on providers using gist (location);

-- Un prestataire est visible s'il est vérifié, en ligne et abonné (7 jours de grâce)
create or replace function provider_is_visible(p providers) returns boolean
language sql stable as $$
  select p.status = 'verified'
     and p.is_online
     and p.subscription_until is not null
     and p.subscription_until + 7 >= current_date;
$$;

-- ---------- Documents prestataires ----------
create table provider_documents (
  id           uuid primary key default gen_random_uuid(),
  provider_id  uuid not null references providers(id) on delete cascade,
  doc_type     text not null,   -- 'registre_commerce','carte_grise','assurance','agrement_wilaya','identite'
  file_path    text not null,   -- chemin dans le bucket privé 'documents'
  status       provider_status not null default 'pending',
  created_at   timestamptz not null default now()
);

-- ---------- Abonnements payés par virement (hors application) ----------
create table subscription_payments (
  id            uuid primary key default gen_random_uuid(),
  provider_id   uuid not null references providers(id) on delete cascade,
  months        int  not null check (months in (1, 3, 12)),
  amount_da     int  not null,           -- 1500 / 4200 / 15000
  reference     text not null,           -- 'DEP-04217'
  receipt_path  text not null,           -- reçu téléversé (bucket 'receipts')
  status        payment_status not null default 'submitted',
  validated_by  uuid references profiles(id),
  validated_at  timestamptz,
  created_at    timestamptz not null default now()
);

-- Validation par l'admin : prolonge l'abonnement
create or replace function validate_payment(payment_id uuid) returns void
language plpgsql security definer as $$
declare pay subscription_payments;
begin
  if (select role from profiles where id = auth.uid()) <> 'admin' then
    raise exception 'admin only';
  end if;
  select * into pay from subscription_payments where id = payment_id for update;
  update subscription_payments
     set status = 'validated', validated_by = auth.uid(), validated_at = now()
   where id = payment_id;
  update providers
     set subscription_until = greatest(coalesce(subscription_until, current_date), current_date)
                              + (pay.months * 30)
   where id = pay.provider_id;
end $$;

-- ---------- Demandes ----------
create table requests (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references profiles(id),
  provider_id      uuid references providers(id),
  axis             service_axis not null,
  category_id      text not null references categories(id),
  pickup           geography(point, 4326) not null,
  pickup_label     text,
  destination      text,
  scheduled_at     timestamptz,               -- transport programmé (ambulance)
  round_trip       boolean not null default false,
  note             text,                      -- jamais de diagnostic médical
  status           request_status not null default 'sent',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table request_tracking (
  id          bigserial primary key,
  request_id  uuid not null references requests(id) on delete cascade,
  lat         double precision not null,     -- lisible directement par l'app (flux temps réel)
  lng         double precision not null,
  location    geography(point, 4326) generated always as (st_makepoint(lng, lat)::geography) stored,
  recorded_at timestamptz not null default now()
);

-- ---------- Avis ----------
create table reviews (
  request_id  uuid primary key references requests(id) on delete cascade,
  provider_id uuid not null references providers(id),
  client_id   uuid not null references profiles(id),
  stars       int not null check (stars between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now()
);

-- ---------- Publicités (régie directe) ----------
create table ads (
  id          uuid primary key default gen_random_uuid(),
  surface     ad_surface not null,
  slot        text not null,              -- 'home_banner','list_sponsored','end_interstitial','pro_dashboard'…
  wilayas     text[] not null default '{}',  -- vide = toutes
  advertiser  text not null,
  image_path  text not null,
  link_url    text,
  starts_on   date not null,
  ends_on     date not null,
  impressions bigint not null default 0,
  clicks      bigint not null default 0
);

-- =====================================================================
-- Recherche des prestataires les plus proches
-- =====================================================================
create or replace function nearby_providers(
  lat double precision, lng double precision,
  p_axis service_axis, p_category text default null, max_km int default 30
) returns table (
  id uuid, business_name text, vehicle_desc text, distance_km numeric,
  rating_avg numeric, rating_count int, base_price_da int, lat double precision, lng double precision
) language sql stable security definer as $$
  select p.id, p.business_name, p.vehicle_desc,
         round((st_distance(p.location, st_makepoint(lng, lat)::geography) / 1000)::numeric, 1),
         p.rating_avg, p.rating_count, p.base_price_da,
         st_y(p.location::geometry), st_x(p.location::geometry)
    from providers p
   where p.axis = p_axis
     and (p_category is null or p_category = any(p.categories))
     and provider_is_visible(p)
     and st_dwithin(p.location, st_makepoint(lng, lat)::geography, least(max_km, p.radius_km) * 1000)
   order by p.location <-> st_makepoint(lng, lat)::geography
   limit 30;
$$;

-- =====================================================================
-- Sécurité : Row Level Security
-- =====================================================================
alter table profiles              enable row level security;
alter table providers             enable row level security;
alter table provider_documents    enable row level security;
alter table subscription_payments enable row level security;
alter table requests              enable row level security;
alter table request_tracking      enable row level security;
alter table reviews               enable row level security;
alter table ads                   enable row level security;
alter table categories            enable row level security;

create or replace function is_admin() returns boolean language sql stable as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create policy "categories lisibles"     on categories for select using (true);
create policy "profil: soi-même"        on profiles for all using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy "prestataire: soi-même"   on providers for all using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy "documents: propriétaire" on provider_documents for all using (provider_id = auth.uid() or is_admin()) with check (provider_id = auth.uid());
create policy "paiements: propriétaire" on subscription_payments for select using (provider_id = auth.uid() or is_admin());
create policy "paiements: déclarer"     on subscription_payments for insert with check (provider_id = auth.uid() and status = 'submitted');

create policy "demandes: client"        on requests for all using (client_id = auth.uid()) with check (client_id = auth.uid());
-- le prestataire ne voit la demande (et la position) qu'une fois assigné
create policy "demandes: prestataire"   on requests for select using ((provider_id = auth.uid() and status <> 'sent') or is_admin());

-- Demandes reçues, AVANT acceptation : distance seulement, sans position exacte ni téléphone
create or replace function incoming_requests()
returns table (id uuid, category_id text, destination text, distance_km numeric, created_at timestamptz)
language sql stable security definer as $$
  select r.id, r.category_id, r.destination,
         round((st_distance(r.pickup, p.location) / 1000)::numeric, 1), r.created_at
    from requests r join providers p on p.id = r.provider_id
   where r.provider_id = auth.uid() and r.status = 'sent'
     and r.created_at > now() - interval '60 seconds'
   order by r.created_at desc;
$$;
create policy "demandes: maj statut"    on requests for update using (provider_id = auth.uid()) with check (provider_id = auth.uid());

create policy "suivi: parties"          on request_tracking for select using (
  exists (select 1 from requests r where r.id = request_id and (r.client_id = auth.uid() or r.provider_id = auth.uid())));
create policy "suivi: prestataire écrit" on request_tracking for insert with check (
  exists (select 1 from requests r where r.id = request_id and r.provider_id = auth.uid()
          and r.status in ('accepted','en_route','on_site')));

create policy "avis lisibles"           on reviews for select using (true);
create policy "avis: client"            on reviews for insert with check (
  client_id = auth.uid() and exists (select 1 from requests r where r.id = request_id and r.client_id = auth.uid() and r.status = 'done'));

create policy "pubs actives lisibles"   on ads for select using (current_date between starts_on and ends_on or is_admin());
create policy "pubs: admin"             on ads for all using (is_admin()) with check (is_admin());

-- Réponse du prestataire à une demande reçue (accepter / refuser)
create or replace function respond_request(p_request uuid, p_accept boolean) returns void
language plpgsql security definer as $$
begin
  update requests
     set status = case when p_accept then 'accepted'::request_status else 'expired'::request_status end,
         updated_at = now()
   where id = p_request and provider_id = auth.uid() and status = 'sent';
  if not found then raise exception 'demande introuvable ou déjà traitée'; end if;
end $$;

-- Coordonnées révélées uniquement une fois la demande acceptée
create or replace function request_contacts(p_request uuid)
returns table (client_phone text, provider_phone text)
language sql stable security definer as $$
  select c.phone, p.phone
    from requests r join profiles c on c.id = r.client_id join profiles p on p.id = r.provider_id
   where r.id = p_request
     and r.status in ('accepted','en_route','on_site')
     and auth.uid() in (r.client_id, r.provider_id);
$$;

-- Position du client, révélée au prestataire seulement après acceptation
create or replace function request_pickup(p_request uuid)
returns table (lat double precision, lng double precision)
language sql stable security definer as $$
  select st_y(r.pickup::geometry), st_x(r.pickup::geometry)
    from requests r
   where r.id = p_request and r.provider_id = auth.uid()
     and r.status in ('accepted','en_route','on_site');
$$;

-- Buckets de stockage privés : documents prestataires et reçus de virement ; 'ads' public
insert into storage.buckets (id, name, public) values
  ('documents', 'documents', false), ('receipts', 'receipts', false), ('ads', 'ads', true)
on conflict do nothing;

create policy "fichiers: dossier perso" on storage.objects for all
  using (bucket_id in ('documents','receipts') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('documents','receipts') and (storage.foldername(name))[1] = auth.uid()::text);

-- Temps réel
alter publication supabase_realtime add table requests, request_tracking;
