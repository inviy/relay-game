-- RELAY 랭킹 백엔드 — Supabase SQL Editor에 그대로 붙여넣고 Run
create table if not exists public.scores (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  day date not null,
  client_id text not null,
  nick text not null check (char_length(nick) between 1 and 14),
  cc text not null check (cc ~ '^[A-Z]{2}$'),
  time_s int not null check (time_s between 0 and 600),
  kills int not null check (kills >= 0),
  lv int not null check (lv between 1 and 60),
  form text check (form in ('rover','warden','none')),
  won boolean not null default false,
  score int not null,
  unique (day, client_id)
);
create index if not exists scores_day_score_idx on public.scores (day, score desc);

alter table public.scores enable row level security;
drop policy if exists "public read" on public.scores;
create policy "public read" on public.scores for select using (true);

create or replace function public.submit_score(
  p_client text, p_nick text, p_cc text,
  p_time int, p_kills int, p_lv int, p_form text, p_won boolean
) returns table (rank int, score int)
language plpgsql security definer set search_path = public as $$
declare v_day date := (now() at time zone 'Asia/Seoul')::date;
        v_score int;
begin
  if p_client is null or char_length(p_client) < 8 then raise exception 'bad client'; end if;
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;
  if p_lv > 4 + p_time / 8 then raise exception 'level too high'; end if;
  if p_won and p_time < 420 then raise exception 'won too early'; end if;

  v_score := p_kills*10 + p_time*4 + p_lv*80 + case when p_won then 4000 else 0 end;

  insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score)
  values (v_day, p_client, left(p_nick,14), upper(left(p_cc,2)), p_time, p_kills, p_lv, p_form, p_won, v_score)
  on conflict (day, client_id) do update
    set nick=excluded.nick, cc=excluded.cc, time_s=excluded.time_s, kills=excluded.kills,
        lv=excluded.lv, form=excluded.form, won=excluded.won, score=excluded.score, created_at=now()
    where excluded.score > public.scores.score;

  return query
    select (select count(*)+1 from public.scores s where s.day=v_day and s.score > v_score)::int,
           v_score;
end $$;

grant execute on function public.submit_score(text,text,text,int,int,int,text,boolean) to anon, authenticated;

create or replace view public.daily_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form,
         rank() over (order by score desc)::int as rank
  from public.scores
  where day = (now() at time zone 'Asia/Seoul')::date
  order by score desc limit 50;

create or replace view public.all_time_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day,
         rank() over (order by score desc)::int as rank
  from public.scores
  order by score desc limit 50;

grant select on public.daily_top, public.all_time_top to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 마이그레이션 · 2026-09-10 — 순위 기간을 하루에서 30일로
-- Supabase SQL Editor에 이 블록만 붙여넣고 Run 하면 됩니다.
-- 데이터는 건드리지 않고 뷰만 다시 만듭니다. 되돌리려면 이전 뷰 정의를 다시 실행하세요.
-- ═══════════════════════════════════════════════════════════════

-- 최근 30일 롤링 순위. 달력 월이 아니라 롤링이라 월초에 보드가 비지 않는다.
-- distinct on (client_id) — 30일로 넓히면 한 사람이 여러 줄을 차지하므로 최고 기록만 남긴다.
create or replace view public.recent_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day,
         rank() over (order by score desc)::int as rank
  from (
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day
    from public.scores
    where day >= (now() at time zone 'Asia/Seoul')::date - 29
    order by client_id, score desc
  ) t
  order by score desc limit 50;

-- 전체 순위도 사람별 최고 기록만. 기존에는 한 사람이 여러 줄을 차지했다.
create or replace view public.all_time_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day,
         rank() over (order by score desc)::int as rank
  from (
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day
    from public.scores
    order by client_id, score desc
  ) t
  order by score desc limit 50;

grant select on public.recent_top to anon, authenticated;
