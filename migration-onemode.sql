-- ═══════════════════════════════════════════════════════════════════════
--  RELAY · 모드 통합 (v2.1.0)
--  Supabase SQL Editor에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
--
--  왜: 4분/5분 제한을 두고 그때 끊는 게 "생소하다"는 실제 피드백이 왔고,
--  신규 유저 둘은 1:26·3:37에 죽어 제한을 보지도 못했다. 모드 선택도 해보기
--  전에는 고를 근거가 없다. 그래서 모드를 하나로 합치고 시간 제한을 없앴다.
--
--  이제 게임은 항상 pace 2(진행 2배 압축)로 돈다. 검증도 진행 시간 기준이어야
--  한다 — 실제 기록 '니니 3:37 LV32'는 실시간 기준 상한 27에 걸려 거부된다.
--  진행 시간(t×2=434초) 기준이면 상한 52로 통과한다.
--
--  바뀌는 것은 둘뿐이다.
--   1) v_eff를 모드와 무관하게 t×2로 고정
--   2) 'daily too long'(305초 상한) 삭제 — 이제 판이 8분까지 간다
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
  if p_kills > p_time * 25 then raise exception 'kills too high'; end if;

  -- 진행 시간. 게임이 항상 2배로 압축해 돌아가므로 검증도 같은 축을 쓴다.
  v_eff := p_time * 2;
  v_lvcap := 12 + floor(v_eff / 22.0)::int + floor(v_eff * v_eff / 9000.0)::int;
  if p_lv > v_lvcap then raise exception 'level too high (%>%)', p_lv, v_lvcap; end if;

  -- 첫 재머가 진행 340초(실 170초)에 온다. 그전에 격파는 불가능하다.
  if p_won and v_eff < 340 then raise exception 'won too early'; end if;

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
             where s.day=v_day and s.score > v_score)::int,
           v_score;
end $$;

grant execute on function public.submit_score(text,text,text,int,int,int,text,boolean,text,text)
  to anon, authenticated;
