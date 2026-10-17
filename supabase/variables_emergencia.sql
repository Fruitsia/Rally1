-- =====================================================================
-- NUNC · Variables para la toma de decisiones en emergencias municipales
-- Migración ADITIVA: se ejecuta DESPUÉS de esquema.sql.
-- No borra ni modifica tablas existentes. Se puede volver a correr sin
-- errores (Supabase → SQL Editor → New query → Run).
--
-- Ver «Variables_Emergencias_Nunc.docx» para el detalle de cada variable.
-- Regla: null = «no se sabe», nunca «cero».
-- =====================================================================


-- =====================================================================
-- 1. EVENTOS (amenaza)
-- =====================================================================
create table if not exists public.eventos (
  id                    uuid primary key default gen_random_uuid(),
  tipo_evento           text not null check (tipo_evento in
                          ('sismo','inundacion','huracan','deslizamiento',
                           'erupcion','incendio','tsunami','otro')),
  severidad_valor       double precision,
  severidad_unidad      text check (severidad_unidad in ('mm_h','km_h','magnitud','metros','otra')),
  indice_severidad      double precision check (indice_severidad between 0 and 1),
  fase                  text not null default 'durante' check (fase in ('antes','durante','despues')),
  tendencia             text not null default 'estable' check (tendencia in ('aumenta','estable','disminuye')),
  ventana_impacto_horas double precision check (ventana_impacto_horas >= 0),
  radio_afectacion_km   double precision check (radio_afectacion_km >= 0),
  poligono_geografico   jsonb,          -- GeoJSON Polygon, orden [longitud, latitud]
  departamento          text,
  municipio             text,
  -- Alerta OFICIAL: la declara la autoridad (Ley 337). La app solo la muestra.
  nivel_alerta_oficial  text check (nivel_alerta_oficial in ('verde','amarilla','roja')),
  alerta_declarada_por  text,
  alerta_declarada_en   timestamptz,
  -- Sugerencia calculada por la app para el coordinador.
  nivel_alerta_sugerido text check (nivel_alerta_sugerido in ('verde','amarilla','roja')),
  coordinador_id        uuid references auth.users on delete set null,
  fuente                text not null default 'institucion'
                        check (fuente in ('ciudadano','lider_comunidad','institucion','sensor','sistema')),
  confiabilidad         double precision not null default 0.8 check (confiabilidad between 0 and 1),
  activo                boolean not null default true,
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now()
);

create index if not exists eventos_activos_idx on public.eventos (activo, municipio);


-- =====================================================================
-- 2. SITUACIÓN POR ZONA (población, servicios y recursos agregados)
-- Una fila por evento + zona. Los valores «calculados» van en la vista
-- situacion_zona_calculada, no se escriben a mano.
-- =====================================================================
create table if not exists public.situacion_zona (
  id                              uuid primary key default gen_random_uuid(),
  evento_id                       uuid not null references public.eventos on delete cascade,
  departamento                    text,
  municipio                       text not null,
  zona                            text not null,       -- barrio, comarca o sector
  -- Población expuesta
  total_personas_expuestas        int check (total_personas_expuestas >= 0),
  total_familias_expuestas        int check (total_familias_expuestas >= 0),
  ninos_expuestos                 int check (ninos_expuestos >= 0),            -- 0 a 12 (Ley 287)
  adolescentes_expuestos          int check (adolescentes_expuestos >= 0),     -- 13 a 17
  adultos_mayores_expuestos       int check (adultos_mayores_expuestos >= 0),  -- 60+ (Ley 720)
  personas_discapacidad_expuestas int check (personas_discapacidad_expuestas >= 0),
  embarazadas_expuestas           int check (embarazadas_expuestas >= 0),
  personas_evacuadas              int check (personas_evacuadas >= 0),
  -- Servicios básicos
  servicio_agua                   text not null default 'desconocido'
                                  check (servicio_agua in ('operativo','parcial','caido','desconocido')),
  servicio_energia                text not null default 'desconocido'
                                  check (servicio_energia in ('operativo','parcial','caido','desconocido')),
  servicio_telecom                text not null default 'desconocido'
                                  check (servicio_telecom in ('operativo','parcial','caido','desconocido')),
  servicio_agua_cobertura_pct     double precision check (servicio_agua_cobertura_pct between 0 and 100),
  servicio_energia_cobertura_pct  double precision check (servicio_energia_cobertura_pct between 0 and 100),
  servicio_telecom_cobertura_pct  double precision check (servicio_telecom_cobertura_pct between 0 and 100),
  -- Recursos
  ambulancias_activas             int check (ambulancias_activas >= 0),
  ambulancias_asignadas           int check (ambulancias_asignadas >= 0),
  personal_bomberos               int check (personal_bomberos >= 0),
  personal_policia                int check (personal_policia >= 0),
  personal_salud                  int check (personal_salud >= 0),
  personal_brigadistas            int check (personal_brigadistas >= 0),
  maquinaria_pesada_disponible    int check (maquinaria_pesada_disponible >= 0),
  embarcaciones_disponibles       int check (embarcaciones_disponibles >= 0),
  raciones_alimento               int check (raciones_alimento >= 0),
  litros_agua_disponibles         double precision check (litros_agua_disponibles >= 0),
  -- Metadatos
  fuente                          text not null default 'lider_comunidad'
                                  check (fuente in ('ciudadano','lider_comunidad','institucion','sensor','sistema')),
  confiabilidad                   double precision not null default 0.6 check (confiabilidad between 0 and 1),
  actualizado_por                 uuid default auth.uid() references auth.users on delete set null,
  actualizado_en                  timestamptz not null default now(),
  unique (evento_id, municipio, zona)
);


-- =====================================================================
-- 3. VÍAS, CENTROS DE SALUD, ALBERGUES, PUNTOS CRÍTICOS Y EQUIPOS
-- =====================================================================
create table if not exists public.vias (
  id                    uuid primary key default gen_random_uuid(),
  evento_id             uuid not null references public.eventos on delete cascade,
  municipio             text not null,
  zona                  text,
  nombre                text not null,
  estado                text not null default 'desconocido'
                        check (estado in ('transitable','solo_4x4','solo_a_pie','bloqueada','desconocido')),
  geometria             jsonb,          -- GeoJSON LineString
  capacidad_vehiculos   int not null default 4 check (capacidad_vehiculos > 0),
  vehiculos_en_ruta     int not null default 0 check (vehiculos_en_ruta >= 0),
  actualizado_en        timestamptz not null default now()
);

create table if not exists public.centros_salud (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  municipio      text not null,
  latitud        double precision not null,
  longitud       double precision not null,
  operativo      boolean not null default true,
  camas_totales  int not null default 0 check (camas_totales >= 0),
  camas_ocupadas int not null default 0 check (camas_ocupadas >= 0),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.albergues (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null,
  municipio      text not null,
  comunidad      text,
  latitud        double precision not null,
  longitud       double precision not null,
  activo         boolean not null default false,
  accesible      boolean not null default false,   -- apto para personas con discapacidad
  capacidad      int not null default 0 check (capacidad >= 0),
  ocupacion      int not null default 0 check (ocupacion >= 0),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.puntos_criticos (
  id                 uuid primary key default gen_random_uuid(),
  tipo               text not null check (tipo in ('gasolinera','puente','subestacion','quimicos','presa','otro')),
  nombre             text not null,
  municipio          text not null,
  latitud            double precision not null,
  longitud           double precision not null,
  activo             boolean not null default false,   -- representa peligro ahora
  radio_seguridad_km double precision not null default 0.3
);

create table if not exists public.equipos (
  id             uuid primary key default gen_random_uuid(),
  evento_id      uuid not null references public.eventos on delete cascade,
  institucion_id int references public.instituciones,
  tipo           text not null check (tipo in
                   ('bomberos','salud_cruz_roja','proteccion_civil','policia','brigada_comunitaria')),
  integrantes    int not null default 1 check (integrantes > 0),
  es_4x4         boolean not null default false,
  estado         text not null default 'disponible'
                 check (estado in ('disponible','en_camino','en_sitio','descanso')),
  reporte_id     uuid references public.reportes on delete set null,
  via_id         uuid references public.vias on delete set null,
  actualizado_en timestamptz not null default now()
);


-- =====================================================================
-- 4. SOS CON ACOMPAÑAMIENTO
-- El sos_id lo genera el teléfono: reintentar no duplica.
-- =====================================================================
create table if not exists public.sos (
  id                   uuid primary key,                 -- = sos_id del teléfono
  usuario_id           uuid default auth.uid() references auth.users on delete set null,
  reporte_id           uuid references public.reportes on delete set null,
  tipo                 text not null,
  estado_usuario       text not null default 'emergencia'
                       check (estado_usuario in ('a_salvo','precaucion','emergencia','sin_respuesta')),
  etapa                text not null default 'normal'
                       check (etapa in ('normal','preguntando','alarma','aviso_lider','derivado','cerrado')),
  bateria_pct          smallint check (bateria_pct between 0 and 100),
  conectividad         text check (conectividad in ('datos','solo_sms','sin_senal')),
  ultima_latitud       double precision,
  ultima_longitud      double precision,
  ultima_precision_m   double precision,
  origen_ubicacion     text check (origen_ubicacion in ('gps','red','ultima_conocida','manual')),
  ultima_interaccion   timestamptz,
  ultimo_movimiento    timestamptz,
  personas_con_usuario smallint check (personas_con_usuario >= 0),
  departamento         text,
  municipio            text,
  comunidad            text,
  creado_en            timestamptz not null default now(),
  actualizado_en       timestamptz not null default now(),
  cerrado_en           timestamptz
);

create index if not exists sos_activos_idx on public.sos (etapa, comunidad) where etapa <> 'cerrado';

-- Recorrido. Se borra 30 días después de cerrar el SOS (ver sección 7).
create table if not exists public.sos_ubicaciones (
  id          bigint generated always as identity primary key,
  sos_id      uuid not null references public.sos on delete cascade,
  latitud     double precision not null,
  longitud    double precision not null,
  precision_m double precision,
  origen      text check (origen in ('gps','red','ultima_conocida','manual')),
  hora        timestamptz not null
);

create index if not exists sos_ubicaciones_idx on public.sos_ubicaciones (sos_id, hora desc);

-- Contactos de emergencia (máx. 3 por persona, se controla en la app).
create table if not exists public.contactos_emergencia (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  nombre     text not null,
  telefono   text not null,
  parentesco text
);

-- Ficha médica OPCIONAL y voluntaria. Solo se comparte con un SOS activo.
create table if not exists public.fichas_medicas (
  user_id     uuid primary key default auth.uid() references auth.users on delete cascade,
  tipo_sangre text,
  alergias    text,
  condiciones text,
  consentido  boolean not null default false,
  actualizado_en timestamptz not null default now()
);


-- =====================================================================
-- 5. TRIGGERS DE «actualizado_en» (usa la función de esquema.sql)
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['eventos','situacion_zona','vias','centros_salud',
                           'albergues','equipos','sos','fichas_medicas']
  loop
    execute format('drop trigger if exists trg_%1$s_actualizado on public.%1$I', t);
    execute format(
      'create trigger trg_%1$s_actualizado before update on public.%1$I
         for each row execute function public.tocar_actualizado()', t);
  end loop;
end $$;


-- =====================================================================
-- 6. VISTA CON LAS VARIABLES CALCULADAS (sección 8 del documento)
-- =====================================================================
create or replace view public.situacion_zona_calculada
with (security_invoker = true) as
with miembros as (
  -- Estado de las personas a partir de los SOS activos de las últimas 72 h.
  select comunidad,
         count(*) filter (where estado_usuario = 'a_salvo')       as personas_a_salvo,
         count(*) filter (where estado_usuario = 'precaucion')    as personas_precaucion,
         count(*) filter (where estado_usuario = 'emergencia')    as personas_emergencia,
         count(*) filter (where estado_usuario = 'sin_respuesta') as personas_sin_respuesta,
         count(*)                                                 as registrados
  from public.sos
  where creado_en > now() - interval '72 hours'
  group by comunidad
),
accesos as (
  select evento_id, zona,
         count(*) as total_vias,
         count(*) filter (where estado = 'transitable') as vias_transitables,
         count(*) filter (where estado = 'solo_4x4')    as vias_solo_4x4,
         count(*) filter (where estado = 'bloqueada')   as vias_bloqueadas,
         count(*) filter (where estado in ('bloqueada','solo_a_pie')) as vias_aisladas
  from public.vias
  group by evento_id, zona
)
select
  s.*,
  e.tipo_evento,
  e.nivel_alerta_oficial,
  case when s.total_personas_expuestas > 0
       then least(100, 100.0 * coalesce(s.personas_evacuadas, 0) / s.total_personas_expuestas)
  end as tasa_evacuacion_pct,
  case when s.total_personas_expuestas > 0
       then least(1, (coalesce(s.ninos_expuestos,0) + coalesce(s.adultos_mayores_expuestos,0)
                    + coalesce(s.personas_discapacidad_expuestas,0) + coalesce(s.embarazadas_expuestas,0))::double precision
                    / s.total_personas_expuestas)
  end as proporcion_vulnerable,
  greatest(0, coalesce(s.ambulancias_activas,0) - coalesce(s.ambulancias_asignadas,0)) as ambulancias_disponibles,
  coalesce(a.vias_transitables, 0) as vias_transitables,
  coalesce(a.vias_solo_4x4, 0)     as vias_solo_4x4,
  coalesce(a.vias_bloqueadas, 0)   as vias_bloqueadas,
  coalesce(m.personas_a_salvo, 0)       as personas_a_salvo,
  coalesce(m.personas_precaucion, 0)    as personas_precaucion,
  coalesce(m.personas_emergencia, 0)    as personas_emergencia,
  coalesce(m.personas_sin_respuesta, 0) as personas_sin_respuesta,
  -- Prioridad 0 a 100: 0,30·S + 0,25·V + 0,15·A + 0,15·T + 0,15·R
  round((100 * (
      0.30 * coalesce(e.indice_severidad, 0.5)
    + 0.25 * coalesce(least(1, (coalesce(s.ninos_expuestos,0) + coalesce(s.adultos_mayores_expuestos,0)
                              + coalesce(s.personas_discapacidad_expuestas,0) + coalesce(s.embarazadas_expuestas,0))::double precision
                              / nullif(s.total_personas_expuestas, 0)), 0)
    + 0.15 * coalesce(a.vias_aisladas::double precision / nullif(a.total_vias, 0), 1)
    + 0.15 * case when e.fase = 'durante' then 1
                  when e.ventana_impacto_horas is null then 0.5
                  else 1 - least(e.ventana_impacto_horas, 24) / 24 end
    + 0.15 * coalesce((m.personas_emergencia + m.personas_sin_respuesta)::double precision
                      / nullif(m.registrados, 0), 0)
  ))::numeric, 1) as indice_prioridad_zona
from public.situacion_zona s
join public.eventos e on e.id = s.evento_id
left join accesos  a on a.evento_id = s.evento_id and a.zona = s.zona
left join miembros m on m.comunidad = s.zona;


-- =====================================================================
-- 7. SEGURIDAD (RLS)
-- =====================================================================
alter table public.eventos              enable row level security;
alter table public.situacion_zona       enable row level security;
alter table public.vias                 enable row level security;
alter table public.centros_salud        enable row level security;
alter table public.albergues            enable row level security;
alter table public.puntos_criticos      enable row level security;
alter table public.equipos              enable row level security;
alter table public.sos                  enable row level security;
alter table public.sos_ubicaciones      enable row level security;
alter table public.contactos_emergencia enable row level security;
alter table public.fichas_medicas       enable row level security;

-- ¿El SOS existe y sigue abierto? (security definer: quien envía sin cuenta
-- no puede leer la tabla sos, pero sí necesita agregar ubicaciones).
create or replace function public.sos_esta_activo(p_sos uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.sos where id = p_sos and etapa <> 'cerrado');
$$;
grant execute on function public.sos_esta_activo(uuid) to anon, authenticated;

-- Información pública útil para orientar a la población (sin datos personales).
drop policy if exists "leer eventos" on public.eventos;
create policy "leer eventos" on public.eventos         for select using (true);
drop policy if exists "leer vias" on public.vias;
create policy "leer vias" on public.vias            for select using (true);
drop policy if exists "leer centros salud" on public.centros_salud;
create policy "leer centros salud" on public.centros_salud   for select using (true);
drop policy if exists "leer albergues" on public.albergues;
create policy "leer albergues" on public.albergues       for select using (true);
drop policy if exists "leer puntos criticos" on public.puntos_criticos;
create policy "leer puntos criticos" on public.puntos_criticos for select using (true);

-- Gestión operativa: solo autoridades y líderes.
drop policy if exists "autoridad gestiona eventos" on public.eventos;
create policy "autoridad gestiona eventos" on public.eventos
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona situacion" on public.situacion_zona;
create policy "autoridad gestiona situacion" on public.situacion_zona
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona vias" on public.vias;
create policy "autoridad gestiona vias" on public.vias
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona centros" on public.centros_salud;
create policy "autoridad gestiona centros" on public.centros_salud
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona albergues" on public.albergues;
create policy "autoridad gestiona albergues" on public.albergues
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona puntos" on public.puntos_criticos;
create policy "autoridad gestiona puntos" on public.puntos_criticos
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());
drop policy if exists "autoridad gestiona equipos" on public.equipos;
create policy "autoridad gestiona equipos" on public.equipos
  for all to authenticated using (public.es_autoridad()) with check (public.es_autoridad());

-- SOS: se puede enviar sin cuenta; cada quien ve el suyo; las autoridades
-- ven los SOS (el líder, en la app, filtra por su comunidad).
drop policy if exists "crear sos sin cuenta" on public.sos;
create policy "crear sos sin cuenta" on public.sos
  for insert to anon with check (usuario_id is null);
drop policy if exists "crear sos con cuenta" on public.sos;
create policy "crear sos con cuenta" on public.sos
  for insert to authenticated with check (usuario_id = (select auth.uid()));
drop policy if exists "actualizar mi sos" on public.sos;
create policy "actualizar mi sos" on public.sos
  for update to authenticated
  using (usuario_id = (select auth.uid()) or public.es_autoridad())
  with check (usuario_id = (select auth.uid()) or public.es_autoridad());
drop policy if exists "ver sos" on public.sos;
create policy "ver sos" on public.sos
  for select to authenticated
  using (usuario_id = (select auth.uid()) or public.es_autoridad());

drop policy if exists "agregar ubicacion" on public.sos_ubicaciones;
create policy "agregar ubicacion" on public.sos_ubicaciones
  for insert to anon, authenticated
  with check (public.sos_esta_activo(sos_id));
drop policy if exists "ver ubicaciones" on public.sos_ubicaciones;
create policy "ver ubicaciones" on public.sos_ubicaciones
  for select to authenticated
  using (public.es_autoridad()
         or exists (select 1 from public.sos s where s.id = sos_id and s.usuario_id = (select auth.uid())));

drop policy if exists "mis contactos" on public.contactos_emergencia;
create policy "mis contactos" on public.contactos_emergencia
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "mi ficha medica" on public.fichas_medicas;
create policy "mi ficha medica" on public.fichas_medicas
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- La autoridad solo ve la ficha si la persona consintió y tiene un SOS activo.
drop policy if exists "ficha con sos activo" on public.fichas_medicas;
create policy "ficha con sos activo" on public.fichas_medicas
  for select to authenticated
  using (public.es_autoridad() and consentido and exists (
    select 1 from public.sos s
    where s.usuario_id = fichas_medicas.user_id and s.etapa <> 'cerrado'));

-- Limpieza de privacidad: borra recorridos de SOS cerrados hace más de 30 días.
-- Ejecútala a diario con Supabase Cron (pg_cron) o manualmente.
create or replace function public.limpiar_recorridos_sos()
returns void language sql security definer set search_path = '' as $$
  delete from public.sos_ubicaciones u
  using public.sos s
  where s.id = u.sos_id and s.etapa = 'cerrado'
    and s.cerrado_en < now() - interval '30 days';
$$;


-- =====================================================================
-- 8. TIEMPO REAL (panel de líder y mapa)
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['sos','vias','equipos'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
