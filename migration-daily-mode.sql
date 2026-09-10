-- ═══════════════════════════════════════════════════════════════════════
--  RELAY 마이그레이션 · 오늘의 중계 모드 + 레벨 상한 수정 (v2.0)
--  이 파일 전체를 Supabase SQL Editor에 붙여넣고 Run 한 번만 하면 됩니다.
--  앞서 드린 migration-levelcap.sql을 아직 안 돌리셨다면 이 파일이 대신합니다
--  (그 내용이 전부 들어 있습니다). 여러 번 실행해도 안전합니다.
--
--  하는 일
--   1. 레벨 상한 재설계 — 정상 기록이 잘리던 버그
--   2. mode 컬럼 — 오늘의 중계(4분) / 심층(무한)을 분리
--   3. 순위표를 모드별로 분리
--   4. 거부됐던 101,752점 복구
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. mode 컬럼 ───────────────────────────────────────────────────────
-- 기존 기록은 전부 심층이다. 4분 모드가 없던 시절 기록이므로 섞으면 안 된다.
alter table public.scores add column if not exists mode text not null default 'endless';
alter table public.scores drop constraint if exists scores_mode_check;
alter table public.scores add  constraint scores_mode_check check (mode in ('daily','endless'));

-- 한 사람이 하루에 두 모드를 각각 하나씩 가질 수 있어야 한다
alter table public.scores drop constraint if exists scores_day_client_id_key;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='scores_day_client_mode_key') then
    alter table public.scores add constraint scores_day_client_mode_key unique (day, client_id, mode);
  end if;
end $$;

-- ── 2. 검증식 재설계 + 모드 수용 ───────────────────────────────────────
-- 레벨의 주 공급원은 처치가 아니라 상자다.
--   p.need = need*1.22+3 → LV15쯤부터 처치 XP로는 레벨업이 사실상 불가능
--   엘리트 처치 시 상자 드롭, 상자는 gainXp(need*1.1) = 레벨 하나를 통째로
--   엘리트는 32초마다 (1 + t/180)마리 → 누적 t/32 + t²/11520
-- 그래서 레벨은 "진행 시간"의 제곱에 붙는다. ln(처치)를 주항으로 쓰면 안 된다.
--
-- 오늘의 중계는 pace=2라 4분이 8분처럼 굴러간다. 검증도 진행 시간으로 해야
-- 정상 기록이 안 잘린다.
-- 구버전 오버로드를 먼저 지운다. 안 지우면 이름 인자 호출이 두 후보에 걸려
-- "function ... is not unique" 로 실패한다 — 배포된 클라이언트가 전부 깨진다.
drop function if exists public.submit_score(text,text,text,int,int,int,text,boolean);
drop function if exists public.submit_score(text,text,text,int,int,int,text,boolean,text);

create or replace function public.submit_score(
  p_client text, p_nick text, p_cc text,
  p_time int, p_kills int, p_lv int, p_form text, p_won boolean,
  p_ch text default null, p_mode text default 'endless'
) returns table (rank int, score int)
language plpgsql security definer set search_path = public as $$
declare v_day  date := (now() at time zone 'Asia/Seoul')::date;
        v_mode text := case when p_mode = 'daily' then 'daily' else 'endless' end;
        v_eff  int;
        v_score int;
        v_lvcap int;
begin
  if p_client is null or char_length(p_client) < 8 then raise exception 'bad client'; end if;
  if v_mode = 'daily' and p_time > 245 then raise exception 'daily too long'; end if;
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;

  v_eff := p_time * (case when v_mode = 'daily' then 2 else 1 end);   -- 진행 시간
  v_lvcap := 12 + floor(v_eff / 22.0)::int + floor(v_eff * v_eff / 9000.0)::int;
  if p_lv > v_lvcap then raise exception 'level too high (%>%)', p_lv, v_lvcap; end if;

  if p_won and v_eff < (case when v_mode = 'daily' then 340 else 420 end)
    then raise exception 'won too early'; end if;

  -- 클라이언트 calcScore()와 반드시 같은 식이어야 한다
  v_score := p_kills*6 + p_time*3 + p_lv*260 + case when p_won then 12000 else 0 end;

  insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score, ch, mode)
  values (v_day, p_client, left(p_nick,14), upper(left(p_cc,2)), p_time, p_kills, p_lv, p_form, p_won,
          v_score, nullif(p_ch,''), v_mode)
  on conflict (day, client_id, mode) do update
    set nick=excluded.nick, cc=excluded.cc, time_s=excluded.time_s, kills=excluded.kills,
        lv=excluded.lv, form=excluded.form, won=excluded.won, score=excluded.score,
        ch=coalesce(excluded.ch, public.scores.ch), created_at=now()
    where excluded.score > public.scores.score;

  return query
    select (select count(*)+1 from public.scores s
             where s.day=v_day and s.mode=v_mode and s.score > v_score)::int,
           v_score;
end $$;

grant execute on function public.submit_score(text,text,text,int,int,int,text,boolean,text,text)
  to anon, authenticated;


-- ── 3. 모드별 순위표 ───────────────────────────────────────────────────
-- 오늘의 중계는 "오늘 하루, 같은 조건" 그 자체가 상품이라 당일만 본다.
create or replace view public.board_daily with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day, ch,
         rank() over (order by score desc)::int as rank
  from public.scores
  where mode = 'daily' and day = (now() at time zone 'Asia/Seoul')::date
  order by score desc limit 50;

-- 심층은 길이가 제각각이라 하루로 끊으면 표가 빈다. 30일 롤링에 사람별 최고 하나.
drop view if exists public.recent_top;
create view public.recent_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day, ch,
         rank() over (order by score desc)::int as rank
  from (
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day, ch
    from public.scores
    where mode = 'endless' and day >= (now() at time zone 'Asia/Seoul')::date - 29
    order by client_id, score desc
  ) t
  order by score desc limit 50;

grant select on public.board_daily, public.recent_top to anon, authenticated;


-- ── 4. 거부됐던 기록 복구 ──────────────────────────────────────────────
-- events 테이블의 end 이벤트 값 그대로다. 추정이 아니다.
--   t=858 · 처치 10,023 · LV104 · rover · relay
--   101752 = 10023*6 + 858*3 + 104*260 + 12000
insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score, ch, mode)
select (now() at time zone 'Asia/Seoul')::date, client_id, nick, cc,
       858, 10023, 104, 'rover', true,
       10023*6 + 858*3 + 104*260 + 12000, 'relay', 'endless'
from public.scores where nick = '똥알이' order by created_at desc limit 1
on conflict (day, client_id, mode) do update
  set time_s=excluded.time_s, kills=excluded.kills, lv=excluded.lv, form=excluded.form,
      won=excluded.won, score=excluded.score, ch=excluded.ch, created_at=now()
  where excluded.score > public.scores.score;
