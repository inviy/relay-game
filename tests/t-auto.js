(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  let sub=0;const f0=window.fetch;window.fetch=(u,o)=>{if(String(u).includes("submit_score"))sub++;return f0(u,o);};
  D.PAID.auto=1;D.PAID.fast=0;D.start();const G=D.G;
  G.zone={x:G.p.x+250,y:G.p.y,r:340};   // 시작점은 원 한가운데라 합력이 0 — 원 밖으로 밀어 방향을 만든다
  const x0=G.p.x,y0=G.p.y;
  for(let i=0;i<60;i++)D.update(1/60);
  ok("AUTO가 움직인다",Math.hypot(G.p.x-x0,G.p.y-y0)>5,[G.p.x-x0,G.p.y-y0]);
  ok("autoUsed",G.autoUsed===true);

  // 사람 입력 우선
  const s=D.autoSteer();D.keys.d=1;const px=G.p.x;D.update(1/60);D.keys.d=0;
  ok("사람 입력 우선",G.p.x>px,[px,G.p.x,s]);

  // 자동 선택: 레벨업 화면을 0.6초 뒤 스스로 닫는다
  if(D.mode!=="level"){G.p.xp=G.p.need;D.gainXp(0.01);}
  ok("레벨업 화면 뜸",D.mode==="level");
  for(let i=0;i<9&&D.mode==="level";i++)D.autoPick();   // 대기 중이던 레벨업까지 비운다
  ok("autoPick이 고름",D.mode!=="level",D.mode);

  // 사람이 먼저 골랐으면 타이머는 아무것도 안 한다
  D.mode="play";D.autoPick();ok("화면 없으면 무동작",D.mode==="play");

  // 3분 생존(정보)
  let died=false;for(let i=0;i<180*30;i++){D.update(1/30);
    if(D.mode==="level"||D.mode==="reveal")D.autoPick(),D.mode==="reveal"&&D.closeReveal();
    if(G.dying>0||G.over){died=true;break;}}
  ok("3분 생존 (정보)",true,{t:Math.round(G.t),lv:G.p.lv,died,weapons:Object.keys(G.w).length});

  // 이어하기 후에도 순위 제외
  if(!G.over){G.t=Math.max(G.t,30);D.saveRun();D.contRun();}
  ok("복원 후 autoUsed 유지",D.G.autoUsed===true);
  D.PAID.auto=0;
  // 이탈 제출과 종료 제출 모두 0건
  D.submitBeacon();D.finish(false);
  ok("AUTO 판 제출 0건",sub===0,sub);
  ok("결과에 순위 제외 표시",/AUTO · 순위 제외/.test(document.getElementById("rankline").textContent));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
