-- ═══════════════════════════════════════════════════════════════════════
--  RELAY · 오늘의 중계를 4분 → 5분으로
--  Supabase SQL Editor에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
--
--  왜: 4분에서는 3차 진화(24레벨)가 한 번도 안 들어왔다. 실측으로 240초는
--  LV21에서 끝나고, 300초면 223초에 3차가 들어와 77초를 그 상태로 쓴다.
--  서버의 'daily too long' 상한만 245 → 305로 올리면 된다.
--  (board_daily에 기록이 없을 때 바꿔야 점수 비교가 안 깨진다.)
-- ═══════════════════════════════════════════════════════════════════════
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
  if v_mode = 'daily' and p_time > 305 then raise exception 'daily too long'; end if;
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;

  v_eff := p_time * (case when v_mode = 'daily' then 2 else 1 end);
  v_lvcap := 12 + floor(v_eff / 22.0)::int + floor(v_eff * v_eff / 9000.0)::int;
  if p_lv > v_lvcap then raise exception 'level too high (%>%)', p_lv, v_lvcap; end if;

  if p_won and v_eff < (case when v_mode = 'daily' then 340 else 420 end)
    then raise exception 'won too early'; end if;

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
