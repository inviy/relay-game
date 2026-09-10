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


-- ═══════════════════════════════════════════════════════════════
-- 마이그레이션 · 2026-09-10 (2차) — 점수 재설계 · 무한 모드 · 기체 기록
-- Supabase SQL Editor에 이 블록만 붙여넣고 Run 하면 됩니다.
--
-- 왜 바꾸나: 기록을 분해해 보니 점수의 80~90%가 처치였고, 처치 수는
-- 스폰(=시간)에 묶여 있어 세 기록이 3213/3273/3567로 수렴했다. 잘해도
-- 점수가 안 올랐다. 반면 레벨은 27~41로 실력이 크게 갈리는데 기여가 6%뿐.
-- ═══════════════════════════════════════════════════════════════

-- 1) 무한 모드 — 보스 격파 후에도 계속 싸운다. 10분 상한을 푼다.
alter table public.scores drop constraint if exists scores_time_s_check;
alter table public.scores add constraint scores_time_s_check check (time_s between 0 and 7200);

-- 2) 시작 기체 기록
alter table public.scores add column if not exists ch text
  check (ch is null or ch in ('relay','runner','shield','tech'));

-- 3) 점수 공식 재설계 + p_ch 수용.
--    p_ch에 기본값을 줘서 아직 갱신 안 된 클라이언트도 그대로 동작한다.
drop function if exists public.submit_score(text,text,text,int,int,int,text,boolean);
create or replace function public.submit_score(
  p_client text, p_nick text, p_cc text,
  p_time int, p_kills int, p_lv int, p_form text, p_won boolean,
  p_ch text default null
) returns table (rank int, score int)
language plpgsql security definer set search_path = public as $$
declare v_day date := (now() at time zone 'Asia/Seoul')::date;
        v_score int;
begin
  if p_client is null or char_length(p_client) < 8 then raise exception 'bad client'; end if;
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;
  if p_lv > 4 + p_time / 8 then raise exception 'level too high'; end if;
  if p_won and p_time < 420 then raise exception 'won too early'; end if;

  -- 클라이언트 calcScore()와 반드시 같은 식이어야 한다
  v_score := p_kills*6 + p_time*3 + p_lv*260 + case when p_won then 12000 else 0 end;

  insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score, ch)
  values (v_day, p_client, left(p_nick,14), upper(left(p_cc,2)), p_time, p_kills, p_lv, p_form, p_won, v_score,
          nullif(p_ch,''))
  on conflict (day, client_id) do update
    set nick=excluded.nick, cc=excluded.cc, time_s=excluded.time_s, kills=excluded.kills,
        lv=excluded.lv, form=excluded.form, won=excluded.won, score=excluded.score,
        ch=coalesce(excluded.ch, public.scores.ch), created_at=now()
    where excluded.score > public.scores.score;

  return query
    select (select count(*)+1 from public.scores s where s.day=v_day and s.score > v_score)::int,
           v_score;
end $$;

grant execute on function public.submit_score(text,text,text,int,int,int,text,boolean,text) to anon, authenticated;

-- 4) 기존 기록을 새 공식으로 재계산. 3건뿐이라 초기화 없이 비교 가능성을 지킨다.
update public.scores
   set score = kills*6 + time_s*3 + lv*260 + case when won then 12000 else 0 end;

-- 5) 뷰에 ch 노출.
--    create or replace view는 컬럼을 맨 뒤에만 추가할 수 있어 ch를 중간에 못 넣는다 → drop 후 재생성.
drop view if exists public.recent_top;
drop view if exists public.all_time_top;
create view public.recent_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day, ch,
         rank() over (order by score desc)::int as rank
  from (
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day, ch
    from public.scores
    where day >= (now() at time zone 'Asia/Seoul')::date - 29
    order by client_id, score desc
  ) t
  order by score desc limit 50;

create view public.all_time_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day, ch,
         rank() over (order by score desc)::int as rank
  from (
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day, ch
    from public.scores
    order by client_id, score desc
  ) t
  order by score desc limit 50;

grant select on public.recent_top, public.all_time_top to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 마이그레이션 · 2026-09-10 (3차) — 무한 모드로 무력화된 검증식 재설계
-- 2차 블록을 이미 실행했다면 이 블록만 실행하면 됩니다.
--
-- 문제: 검증식이 시간에 선형이라 무한 모드에서 사실상 무의미해졌다.
--   4 + p_time/8  → 3600초면 454레벨 허용
--
-- 주의: 레벨은 처치가 아니라 시간에 더 붙는다. 보물 상자가 24초마다
-- 드롭되고 gainXp(need*1.1)로 레벨 하나를 통째로 주기 때문이다.
-- 실측(나라장터 귀신 443초·3567처치·LV41)도 처치 기여 약 27 + 상자 약 14로 설명된다.
-- 그래서 레벨 상한은 처치 로그항 + 시간 선형항을 더해서 잡는다.
--
-- 그리고 아래 검증은 어디까지나 과속방지턱이다. anon 키가 공개돼 있어
-- RPC를 직접 호출할 수 있으므로 작정한 위조를 서버에서 완전히 막을 수는 없다.
-- ═══════════════════════════════════════════════════════════════

-- 레벨 컬럼 제약도 무한 모드에 맞춘다. 2차에서 time_s만 풀고 lv을 빠뜨렸다 —
-- 상자가 24초마다 레벨 하나를 주므로 3600초면 150레벨을 넘길 수 있다.
alter table public.scores drop constraint if exists scores_lv_check;
alter table public.scores add constraint scores_lv_check check (lv between 1 and 500);

create or replace function public.submit_score(
  p_client text, p_nick text, p_cc text,
  p_time int, p_kills int, p_lv int, p_form text, p_won boolean,
  p_ch text default null
) returns table (rank int, score int)
language plpgsql security definer set search_path = public as $$
declare v_day date := (now() at time zone 'Asia/Seoul')::date;
        v_score int; v_lvcap int; v_killcap int; v_killmin int;
begin
  if p_client is null or char_length(p_client) < 8 then raise exception 'bad client'; end if;
  if p_time < 0 or p_kills < 0 or p_lv < 1 then raise exception 'negative value'; end if;

  -- 처치 상한: 스폰 상한 11/s + 분열체 여유 → 14/s
  v_killcap := 60 + p_time * 14;
  if p_kills > v_killcap then raise exception 'kills too high (%>%)', p_kills, v_killcap; end if;

  -- 처치 하한: 안 죽이면 적이 쌓여 살아남을 수 없다. 시간만 부풀린 기록을 막는다.
  -- 실측은 8/s 안팎이므로 1.5/s는 충분히 느슨하다.
  v_killmin := floor(p_time * 1.5)::int;
  if p_time > 120 and p_kills < v_killmin then
    raise exception 'kills too low for survival time (%<%)', p_kills, v_killmin; end if;

  -- 레벨 상한: 처치 로그항 + 상자 선형항(24초당 1레벨을 18초당으로 여유)
  v_lvcap := 10 + floor(ln(greatest(p_kills,1) + 1) * 4)::int + floor(p_time / 18.0)::int;
  if p_lv > v_lvcap then raise exception 'level too high (%>%)', p_lv, v_lvcap; end if;

  if p_won and p_time < 420 then raise exception 'won too early'; end if;

  -- 클라이언트 calcScore()와 반드시 같은 식이어야 한다
  v_score := p_kills*6 + p_time*3 + p_lv*260 + case when p_won then 12000 else 0 end;

  insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score, ch)
  values (v_day, p_client, left(p_nick,14), upper(left(p_cc,2)), p_time, p_kills, p_lv, p_form, p_won, v_score,
          nullif(p_ch,''))
  on conflict (day, client_id) do update
    set nick=excluded.nick, cc=excluded.cc, time_s=excluded.time_s, kills=excluded.kills,
        lv=excluded.lv, form=excluded.form, won=excluded.won, score=excluded.score,
        ch=coalesce(excluded.ch, public.scores.ch), created_at=now()
    where excluded.score > public.scores.score;

  return query
    select (select count(*)+1 from public.scores s where s.day=v_day and s.score > v_score)::int,
           v_score;
end $$;

grant execute on function public.submit_score(text,text,text,int,int,int,text,boolean,text) to anon, authenticated;
