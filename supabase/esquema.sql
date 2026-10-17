-- =====================================================================
-- NUNC · Base de datos desde cero (Supabase / PostgreSQL)
-- Pegar completo en Supabase → SQL Editor → New query → Run.
--
-- ⚠️  El PASO 0 BORRA TODO lo que hay en el esquema "public"
--     (tablas, vistas, funciones y sus datos). No se puede deshacer.
-- =====================================================================


-- =====================================================================
-- 0. BORRAR TODO
-- =====================================================================
do $$
declare r record;
begin
  -- Trigger que crea perfiles al registrarse (vive en auth.users)
  drop trigger if exists on_auth_user_created on auth.users;

  -- (se saltan los objetos que pertenecen a extensiones, p. ej. PostGIS)
  for r in
    select c.relname, c.relkind
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('v','m','r','p')
      and not exists (select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e')
    order by case c.relkind when 'v' then 0 when 'm' then 1 else 2 end
  loop
    execute format(
      case r.relkind when 'v' then 'drop view if exists public.%I cascade'
                     when 'm' then 'drop materialized view if exists public.%I cascade'
                     else 'drop table if exists public.%I cascade' end,
      r.relname);
  end loop;

  for r in
    select p.oid::regprocedure as firma
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('drop function if exists %s cascade', r.firma);
  end loop;
end $$;

-- (Opcional) Borrar también las cuentas de prueba. Descomenta si lo quieres:
-- delete from auth.users;


-- =====================================================================
-- 1. CATÁLOGOS
-- =====================================================================
create table public.instituciones (
  id     int generated always as identity primary key,
  nombre text not null unique,
  tipo   text not null check (tipo in ('policia','bomberos','socorro','proteccion_civil','salud','otro'))
);

insert into public.instituciones (nombre, tipo) values
  ('Policía Nacional',   'policia'),
  ('Cuerpo de Bomberos', 'bomberos'),
  ('Cruz Roja',          'socorro'),
  ('Defensa Civil',      'proteccion_civil'),
  ('Ministerio de Salud','salud');


-- =====================================================================
-- 2. USUARIOS
-- =====================================================================

-- Pantalla REGISTRAR (3 pasos). Se llena SOLA al crear la cuenta, con los
-- datos que la app manda en signUp(data: ...). No hay que insertar desde la app.
create table public.perfiles (
  user_id          uuid primary key references auth.users on delete cascade,
  nombre           text not null default '',
  apellidos        text not null default '',
  edad             smallint check (edad between 1 and 120),
  genero           text,
  oficio           text,          -- Trabajador / Estudiante / Otro
  telefono         text,
  pais_residencia  text,
  pais_procedencia text,
  region           text,
  departamento     text,
  municipio        text,
  comunidad        text,
  creado_en        timestamptz not null default now()
);

-- Pantalla CONFIGURACIÓN
create table public.preferencias (
  user_id                  uuid primary key references auth.users on delete cascade,
  alertas_locales          boolean not null default true,
  noticias_internacionales boolean not null default true,
  reportes_emergencia      boolean not null default true,
  sonido_alerta            boolean not null default false,
  notificaciones_push      boolean not null default true,
  modo_silencioso          boolean not null default false,
  idioma                   text    not null default 'es',
  tamano_texto             text    not null default 'estandar'
                           check (tamano_texto in ('pequeno','estandar','grande'))
);

-- Autoridades y líderes de comunidad.
-- NO se puede modificar desde la app: tú decides quién es autoridad desde el
-- SQL Editor (ver ejemplo al final del archivo).
create table public.autoridades (
  user_id        uuid primary key references auth.users on delete cascade,
  rol            text not null check (rol in ('lider_comunidad','institucion','admin')),
  institucion_id int references public.instituciones,
  cargo          text,
  departamento   text,             -- null = todo el país
  municipio      text,
  comunidad      text              -- para líderes de comunidad
);

create or replace function public.es_autoridad()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.autoridades where user_id = (select auth.uid()));
$$;

-- Crea perfil y preferencias automáticamente cuando alguien se registra.
create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.perfiles (
    user_id, nombre, apellidos, edad, genero, oficio, telefono,
    pais_residencia, pais_procedencia, region, departamento, municipio, comunidad
  ) values (
    new.id,
    coalesce(m->>'nombre', ''),
    coalesce(m->>'apellidos', ''),
    case when (m->>'edad') ~ '^\d{1,3}$' then
      case when (m->>'edad')::int between 1 and 120 then (m->>'edad')::smallint end
    end,
    m->>'genero', m->>'oficio', m->>'telefono',
    m->>'pais_residencia', m->>'pais_procedencia', m->>'region',
    m->>'departamento', m->>'municipio', m->>'comunidad'
  );
  insert into public.preferencias (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.crear_perfil_usuario();


-- =====================================================================
-- 3. ALERTAS OFICIALES
-- Las emiten autoridades / líderes. Al insertarse, las apps abiertas muestran
-- la pantalla "ALERTA" (Supabase Realtime).
-- =====================================================================
create table public.alertas (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null check (tipo in
                 ('terremoto','inundacion','deslizamiento','incendio',
                  'huracan','emergencia_medica','otro')),
  titulo       text not null,
  mensaje      text not null default '',
  departamento text,               -- null = alerta nacional
  municipio    text,
  activa       boolean not null default true,
  emitida_por  uuid default auth.uid() references auth.users on delete set null,
  creado_en    timestamptz not null default now()
);

create index alertas_activas_idx on public.alertas (activa, creado_en desc);


-- =====================================================================
-- 4. REPORTES CIUDADANOS (tríada del semáforo)
--   verde    = "Estoy a salvo"          (tipo 'estado_personal')
--   amarillo = "Estado de precaución"   (tipo 'estado_personal')
--   rojo     = "Emergencia"             (formulario con tipo y dirección)
-- Se pueden enviar SIN cuenta (botón SOS): usuario_id queda en null.
-- =====================================================================
create table public.reportes (
  id             uuid primary key default gen_random_uuid(),
  id_local       text not null unique,   -- lo genera el teléfono: reintentar no duplica
  usuario_id     uuid default auth.uid() references auth.users on delete set null,
  alerta_id      uuid references public.alertas on delete set null,  -- si responde a una alerta
  nivel          text not null check (nivel in ('verde','amarillo','rojo')),
  tipo           text not null check (tipo in
                   ('estado_personal','terremoto','inundacion','emergencia_medica',
                    'incendio','deslizamiento','huracan','persona_atrapada','otro')),
  direccion      text not null default '',   -- escrita a mano ("sin ubicación automática")
  referencia     text not null default '',
  latitud        double precision,           -- opcionales, para cuando haya GPS
  longitud       double precision,
  departamento   text,
  municipio      text,
  comunidad      text,
  estado         text not null default 'recibido'
                 check (estado in ('recibido','en_atencion','resuelto','descartado')),
  institucion_id int  references public.instituciones,   -- quién lo atiende
  atendido_por   uuid references auth.users on delete set null,
  notas          text,
  creado_en      timestamptz not null default now(),   -- hora en el teléfono
  recibido_en    timestamptz not null default now(),   -- hora en que llegó al servidor
  actualizado_en timestamptz not null default now(),
  constraint rojo_requiere_direccion check (nivel <> 'rojo' or direccion <> '')
);

create index reportes_estado_idx    on public.reportes (estado, recibido_en desc);
create index reportes_zona_idx      on public.reportes (departamento, municipio, comunidad);
create index reportes_usuario_idx   on public.reportes (usuario_id);

create or replace function public.tocar_actualizado()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger trg_reportes_actualizado
  before update on public.reportes
  for each row execute function public.tocar_actualizado();

-- Prioridad automática para el panel de autoridades / líderes.
-- Pesa el semáforo, el tipo y el tiempo de espera (+1 cada 10 min, máx. 12).
create or replace view public.reportes_priorizados
with (security_invoker = true) as
select
  r.*,
  ( case r.nivel when 'rojo' then 50 when 'amarillo' then 20 else 0 end
  + case r.tipo
      when 'persona_atrapada'  then 30
      when 'emergencia_medica' then 30
      when 'terremoto'         then 25
      when 'deslizamiento'     then 25
      when 'incendio'          then 25
      when 'inundacion'        then 20
      when 'huracan'           then 20
      when 'estado_personal'   then 0
      else 10 end
  + case when r.estado = 'recibido'
      then least((extract(epoch from now() - r.recibido_en) / 600)::int, 12)
      else 0 end
  ) as puntaje
from public.reportes r
where r.estado not in ('resuelto','descartado');

-- Puntos para el mapa "Mira los lugares afectados" (sin datos personales).
create or replace function public.puntos_mapa()
returns table (nivel text, tipo text, municipio text, comunidad text,
               latitud double precision, longitud double precision, creado_en timestamptz)
language sql stable security definer set search_path = ''
as $$
  select nivel, tipo, municipio, comunidad, latitud, longitud, creado_en
  from public.reportes
  where nivel <> 'verde'
    and estado not in ('resuelto','descartado')
    and creado_en > now() - interval '72 hours';
$$;


-- =====================================================================
-- 5. NOTICIAS (Feed nacional / internacional)
-- =====================================================================
create table public.noticias (
  id         uuid primary key default gen_random_uuid(),
  titulo     text not null,
  resumen    text not null default '',
  categoria  text not null default 'General',
  etiquetas  text[] not null default '{}',
  ambito     text not null default 'nacional' check (ambito in ('nacional','internacional')),
  region     text,
  imagen_url text,
  destacado  boolean not null default false,
  publicada  boolean not null default true,
  creado_en  timestamptz not null default now()
);

create table public.noticias_guardadas (
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  noticia_id uuid not null references public.noticias on delete cascade,
  creado_en  timestamptz not null default now(),
  primary key (user_id, noticia_id)
);

insert into public.noticias (titulo, resumen, categoria, ambito, region, destacado, etiquetas) values
  ('Lluvias continuarán durante el fin de semana', 'Se recomienda evitar zonas bajas y cauces.', 'Clima', 'nacional', 'Nacional', false, '{}'),
  ('Brigadas voluntarias se organizan por barrio', 'Cómo sumarte a la brigada de tu comunidad.', 'Comunidad', 'nacional', 'Nacional', false, '{}'),
  ('Arma tu mochila de emergencia', 'Agua, linterna, botiquín y documentos.', 'Prevención', 'nacional', 'Nacional', false, '{}'),
  ('Cooperación climática: una mirada global', 'Cómo se coordinan países y comunidades frente al cambio climático.', 'Ambiente', 'internacional', 'Mundo', true, '{Europa,Política}'),
  ('Claves para entender la economía mundial', '', 'Economía', 'internacional', 'Mundo', false, '{}'),
  ('Salud: el valor de la cooperación internacional', '', 'Salud', 'internacional', 'Sociedad', false, '{}');


-- =====================================================================
-- 6. DONACIONES
-- =====================================================================
create table public.fundaciones (
  id           uuid primary key default gen_random_uuid(),
  nombre       text not null unique,
  descripcion  text not null default '',
  proyecto     text not null default '',
  departamento text,
  municipio    text,
  moneda       text not null default 'NIO' check (moneda in ('NIO','USD')),
  meta         numeric(12,2) not null default 0 check (meta >= 0),
  recaudado    numeric(12,2) not null default 0 check (recaudado >= 0),
  activa       boolean not null default true
);

insert into public.fundaciones (nombre, descripcion, proyecto, departamento, municipio, moneda, meta, recaudado) values
  ('Fundación Manos Unidas', 'Apoyo alimentario a familias', 'Canastas alimentarias', 'León', 'León', 'NIO', 100000, 68000),
  ('Fundación Sonrisas',     'Útiles y apoyo escolar',       'Apoyo educativo',       'León', 'León', 'USD', 5000, 2050),
  ('Techo Seguro',           'Refugio temporal para damnificados', 'Albergues',       'Managua', 'Managua', 'NIO', 250000, 57500);

-- etapa (pantalla "Ver seguimiento"):
--   1 Donación recibida · 2 Fondos asignados · 3 Ayuda en camino · 4 Entregada
create table public.donaciones (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users on delete cascade,
  fundacion_id uuid not null references public.fundaciones,
  monto        numeric(12,2) not null check (monto > 0),
  moneda       text not null default 'NIO' check (moneda in ('NIO','USD')),
  etapa        smallint not null default 1 check (etapa between 1 and 4),
  creado_en    timestamptz not null default now()
);

create index donaciones_usuario_idx on public.donaciones (user_id, creado_en desc);

-- Suma la donación a lo recaudado por la fundación.
create or replace function public.sumar_recaudado()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.fundaciones set recaudado = recaudado + new.monto
  where id = new.fundacion_id;
  return new;
end;
$$;

create trigger trg_sumar_recaudado
  after insert on public.donaciones
  for each row execute function public.sumar_recaudado();


-- =====================================================================
-- 7. SEGURIDAD (Row Level Security)
--   anon          = app sin sesión (botón SOS)
--   authenticated = usuario con cuenta
-- =====================================================================
alter table public.instituciones      enable row level security;
alter table public.perfiles           enable row level security;
alter table public.preferencias       enable row level security;
alter table public.autoridades        enable row level security;
alter table public.alertas            enable row level security;
alter table public.reportes           enable row level security;
alter table public.noticias           enable row level security;
alter table public.noticias_guardadas enable row level security;
alter table public.fundaciones        enable row level security;
alter table public.donaciones         enable row level security;

-- Catálogos y contenido público
create policy "leer instituciones" on public.instituciones
  for select to anon, authenticated using (true);

create policy "leer noticias" on public.noticias
  for select to anon, authenticated using (publicada or public.es_autoridad());
create policy "autoridad gestiona noticias" on public.noticias
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());

create policy "leer fundaciones" on public.fundaciones
  for select to anon, authenticated using (activa or public.es_autoridad());
create policy "autoridad gestiona fundaciones" on public.fundaciones
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());

-- Perfil y preferencias: cada quien lo suyo (autoridades pueden ver perfiles
-- para contactar a quien reportó)
create policy "ver perfil" on public.perfiles
  for select to authenticated
  using (user_id = (select auth.uid()) or public.es_autoridad());
create policy "editar mi perfil" on public.perfiles
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "mis preferencias" on public.preferencias
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "ver mi rol" on public.autoridades
  for select to authenticated using (user_id = (select auth.uid()));

-- Alertas: todos las leen (necesario para Realtime); solo autoridades emiten
create policy "leer alertas" on public.alertas
  for select to anon, authenticated using (activa or public.es_autoridad());
create policy "autoridad emite alertas" on public.alertas
  for insert to authenticated
  with check (public.es_autoridad() and emitida_por = (select auth.uid()));
create policy "autoridad actualiza alertas" on public.alertas
  for update to authenticated
  using (public.es_autoridad()) with check (public.es_autoridad());

-- Reportes
create policy "enviar reporte sin cuenta" on public.reportes
  for insert to anon
  with check (usuario_id is null and estado = 'recibido' and institucion_id is null);
create policy "enviar reporte con cuenta" on public.reportes
  for insert to authenticated
  with check (usuario_id = (select auth.uid()) and estado = 'recibido' and institucion_id is null);
create policy "ver reportes" on public.reportes
  for select to authenticated
  using (usuario_id = (select auth.uid()) or public.es_autoridad());
create policy "autoridad atiende reportes" on public.reportes
  for update to authenticated
  using (public.es_autoridad()) with check (public.es_autoridad());

-- Noticias guardadas
create policy "mis noticias guardadas" on public.noticias_guardadas
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Donaciones (requieren cuenta)
create policy "ver mis donaciones" on public.donaciones
  for select to authenticated
  using (user_id = (select auth.uid()) or public.es_autoridad());
create policy "donar" on public.donaciones
  for insert to authenticated
  with check (user_id = (select auth.uid()) and etapa = 1);
create policy "autoridad avanza donaciones" on public.donaciones
  for update to authenticated
  using (public.es_autoridad()) with check (public.es_autoridad());

-- La función del mapa la pueden usar todos
grant execute on function public.puntos_mapa() to anon, authenticated;


-- =====================================================================
-- 8. TIEMPO REAL
-- =====================================================================
alter publication supabase_realtime add table public.alertas;
alter publication supabase_realtime add table public.reportes;   -- para el panel de autoridades


-- =====================================================================
-- 9. EJEMPLOS DE USO (descomenta y ejecuta por separado)
-- =====================================================================

-- Convertir una cuenta en líder de comunidad (copia su id desde
-- Authentication → Users):
-- insert into public.autoridades (user_id, rol, departamento, municipio, comunidad)
-- values ('PEGA-AQUI-EL-UUID', 'lider_comunidad', 'León', 'León', 'Sutiaba');

-- Probar la pantalla ALERTA (con la app abierta en Inicio):
-- insert into public.alertas (tipo, titulo, mensaje, departamento)
-- values ('terremoto', 'Sismo fuerte', 'Sismo de magnitud 5.8. Mantén la calma.', 'León');

-- Ver los reportes ordenados por prioridad:
-- select nivel, tipo, direccion, municipio, comunidad, puntaje
-- from public.reportes_priorizados order by puntaje desc;
