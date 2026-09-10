-- ═══════════════════════════════════════════════════════════════════════
--  RELAY · 순위표를 하나로 (기간 제한 없음)
--  Supabase SQL Editor에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
--
--  왜: 사람이 둘뿐인데 모드별로 표를 나누면 양쪽 다 비어 보인다. 30일로
--  끊는 것도 지금은 이르다 — 기록이 쌓일 때까지는 사라지지 않는 편이 낫다.
--  사람이 늘면 board_daily가 이미 있으니 그때 다시 나누면 된다.
-- ═══════════════════════════════════════════════════════════════════════
drop view if exists public.recent_top;
create view public.recent_top with (security_invoker = true) as
  select nick, cc, score, time_s, kills, lv, form, day, ch, mode,
         rank() over (order by score desc)::int as rank
  from (
    -- 사람마다 최고 기록 하나. 모드는 섞는다.
    select distinct on (client_id) client_id, nick, cc, score, time_s, kills, lv, form, day, ch, mode
    from public.scores
    order by client_id, score desc
  ) t
  order by score desc limit 50;

-- security_invoker 뷰라 뷰를 읽을 때 밑의 scores도 호출자 권한으로 읽는다.
-- Supabase는 기본으로 grant가 있지만(그래서 지금 순위표가 뜬다) 명시해 둔다.
grant select on public.scores to anon, authenticated;
grant select on public.recent_top to anon, authenticated;
