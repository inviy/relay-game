-- ═══════════════════════════════════════════════════════════════════════
--  RELAY 마이그레이션 · 분석 이벤트 (v1.9.0)
--  이 파일 전체를 Supabase SQL Editor에 붙여넣고 Run 한 번만 하면 됩니다.
--
--  왜: 지금까지 남는 기록은 순위표뿐이었고, 순위표에는 끝까지 간 사람만
--  올라온다. 생존 편향이라 이탈 지점도, 시작 버튼 클릭률도, 진짜 평균
--  생존시간도 알 수 없었다. 이 테이블이 그 빈칸을 메운다.
--
--  개인정보: 순위표가 이미 쓰고 있는 client_id(무작위 UUID) 외에는
--  아무것도 저장하지 않는다. IP·UA·닉네임 없음.
--  여러 번 실행해도 안전합니다.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.events (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  day        date not null default (now() at time zone 'Asia/Seoul')::date,
  client_id  text not null,
  sid        text not null,          -- 방문(페이지 로드) 단위. land→start 퍼널을 잇는다
  rid        text,                   -- 판 단위. 한 방문에 여러 판을 할 수 있다
  name       text not null,
  ver        text,
  t          int,                    -- 판 경과 초. 판과 무관한 이벤트는 null
  meta       jsonb
);

create index if not exists events_day_name_idx on public.events (day, name);
create index if not exists events_client_day_idx on public.events (client_id, day);

-- 읽기·쓰기 정책을 하나도 두지 않는다 → anon은 테이블에 직접 접근할 수 없고
-- 아래 security definer 함수로만 쓸 수 있다. 조회는 SQL Editor에서만.
alter table public.events enable row level security;

create or replace function public.track(
  p_client text, p_sid text, p_name text, p_rid text default null,
  p_ver text default null, p_t int default null, p_meta jsonb default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_day date := (now() at time zone 'Asia/Seoul')::date;
begin
  -- 실패해도 게임에 영향이 없어야 하므로 예외 대신 조용히 무시한다
  if p_client is null or char_length(p_client) < 8 then return; end if;
  if p_name is null or p_name not in ('land','start','form','end','abandon') then return; end if;

  -- 공개 RPC라 한 사람이 하루에 남길 수 있는 줄 수를 막아 둔다
  if (select count(*) from public.events e
      where e.client_id = p_client and e.day = v_day) >= 500 then return; end if;

  insert into public.events (day, client_id, sid, rid, name, ver, t, meta)
  values (v_day, left(p_client,64), left(coalesce(p_sid,'-'),64), left(p_rid,64), p_name, left(p_ver,16),
          case when p_t is null then null else least(greatest(p_t,0),100000) end,
          p_meta);
end $$;

grant execute on function public.track(text,text,text,text,text,int,jsonb) to anon, authenticated;


-- ── 조회용 뷰 3종 (anon에 권한을 주지 않는다 — SQL Editor 전용) ────────

-- 1) 퍼널: 몇 명이 들어와서 몇 명이 시작 버튼을 눌렀나
create or replace view public.stat_funnel with (security_invoker = true) as
  select day,
         count(distinct client_id)                                as people,
         count(distinct sid)                                      as visits,
         count(distinct sid) filter (where name='start')          as visits_started,
         count(distinct rid) filter (where name='start')          as runs,
         count(distinct rid) filter (where name='end')            as finished,
         round(100.0 * count(distinct sid) filter (where name='start')
                     / nullif(count(distinct sid),0), 1)          as start_pct
  from public.events group by day order by day desc;

-- 2) 이탈 분포: 판이 실제로 몇 초에서 끝나는가.
--    한 판에 abandon이 여러 번 찍힐 수 있다(탭 전환 후 복귀). 판마다 마지막
--    신호만 세야 중복되지 않는다 — distinct on (rid).
create or replace view public.stat_survival with (security_invoker = true) as
  with last as (
    select distinct on (rid) rid, day, name, t
    from public.events
    where rid is not null and name in ('end','abandon') and t is not null
    order by rid, t desc, id desc
  )
  select day,
         count(*)                                     as runs,
         count(*) filter (where name='abandon')       as abandoned,
         round(avg(t))::int                           as avg_s,
         percentile_cont(0.5) within group (order by t)::int as median_s,
         count(*) filter (where t <  30)              as under_30s,
         count(*) filter (where t >= 30  and t < 120) as s30_120,
         count(*) filter (where t >= 120 and t < 300) as s120_300,
         count(*) filter (where t >= 300)             as over_300
  from last group by day order by day desc;

-- 3) 선택 분포: 진화 거부(none)를 정말 아무도 안 고르는지, 기체는 뭘 고르는지
create or replace view public.stat_choice with (security_invoker = true) as
  select name, coalesce(meta->>'form', meta->>'ch', '—') as choice, count(*) as n
  from public.events where name in ('start','form')
  group by 1,2 order by 1, 3 desc;
