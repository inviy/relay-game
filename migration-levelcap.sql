-- ═══════════════════════════════════════════════════════════════════════
--  RELAY 마이그레이션 · 레벨 상한 재설계 + 누락 기록 복구
--  이 파일 전체를 Supabase SQL Editor에 붙여넣고 Run 한 번만 하면 됩니다.
--  여러 번 실행해도 안전합니다.
--
--  왜: 101,752점(t=858 · 처치 10,023 · LV104) 기록이 'level too high'로
--  거부됐다. 검증식이 레벨을 처치 기준으로 잡았는데, 이 게임에서 레벨의
--  주 공급원은 처치가 아니라 상자다.
--
--  근거 (index.html 실측):
--    - p.need = need*1.22+3  → LV15쯤부터 처치 XP로는 레벨업이 사실상 불가능
--    - 엘리트 처치 시 상자 드롭, 상자는 gainXp(need*1.1) = 레벨 하나를 통째로
--    - 엘리트는 32초마다 (1 + t/180)마리  → 누적 t/32 + t²/11520
--    - 시간 상자는 24초마다 4종 중 1종  → 누적 t/96
--    t=858 기준 91 + 9 + 초반 처치 12 ≈ 112레벨. 실제 기록 104와 일치한다.
--
--  그래서 상한을 시간의 제곱항으로 다시 잡는다. 약 27% 여유를 둔다.
--  처치 상한(kills <= time*25)은 그대로라 조작 방어는 유지된다.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.submit_score(
  p_client text, p_nick text, p_cc text,
  p_time int, p_kills int, p_lv int, p_form text, p_won boolean, p_ch text default null
) returns table (rank int, score int)
language plpgsql security definer set search_path = public as $$
declare v_day date := (now() at time zone 'Asia/Seoul')::date;
        v_score int;
        v_lvcap int;
begin
  if p_client is null or char_length(p_client) < 8 then raise exception 'bad client'; end if;
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;

  -- 레벨 상한: 상자가 주 공급원이므로 시간 선형항 + 시간 제곱항
  v_lvcap := 12 + floor(p_time / 22.0)::int + floor(p_time * p_time / 9000.0)::int;
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


-- ── 거부됐던 기록 복구 ─────────────────────────────────────────────────
-- 숫자는 추정이 아니라 events 테이블에 남은 end 이벤트 그대로다:
--   {"ch":"relay","lv":104,"won":false,"form":"rover","cause":"적 탄환",
--    "kills":10023,"score":101752}   t=858
-- won=true인 이유: 점수의 clear 보너스 12,000은 G.cleared(재머 격파) 기준이고
-- 이벤트의 won=false는 "죽어서 끝났다"는 뜻이다. 서버 컬럼은 전자를 받는다.
-- 101752 = 10023*6 + 858*3 + 104*260 + 12000 로 검산된다.
insert into public.scores (day, client_id, nick, cc, time_s, kills, lv, form, won, score, ch)
select (now() at time zone 'Asia/Seoul')::date, client_id, nick, cc,
       858, 10023, 104, 'rover', true,
       10023*6 + 858*3 + 104*260 + 12000, 'relay'
from public.scores
where nick = '똥알이'
order by created_at desc
limit 1
on conflict (day, client_id) do update
  set time_s=excluded.time_s, kills=excluded.kills, lv=excluded.lv, form=excluded.form,
      won=excluded.won, score=excluded.score, ch=excluded.ch, created_at=now()
  where excluded.score > public.scores.score;
