(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=()=>D.G;

  // 1) 같은 시드면 같은 결과
  D.resetSeed();G().w={dart:1,blade:1};G().tier={};G().tierN=0;
  const a=[];for(let i=0;i<20;i++){const r=D.rollTier();a.push(r.k+r.t);}
  D.resetSeed();G().tier={};G().tierN=0;
  const b=[];for(let i=0;i<20;i++){const r=D.rollTier();b.push(r.k+r.t);}
  ok("같은 시드 같은 등급열",a.join()===b.join(),a.slice(0,6));

  // 2) 추첨이 카드 흐름을 건드리지 않는다
  D.resetSeed();for(let i=0;i<10;i++)D.rollTier();const c1=D.R.card();
  D.resetSeed();const c2=D.R.card();
  ok("R.card 불변",c1===c2);

  // 3) 등급은 오르기만 한다 + 중복은 회복
  G().tier={dart:4};G().w={dart:1};G().p.hp=10;
  const r=D.rollTier();ok("신화는 안 내려간다",G().tier.dart===4&&r.up===false);
  G().p.hp=10;G().p.mhp=120;D.openChest({x:G().p.x,y:G().p.y,type:"chest"});
  ok("중복은 체력 +38",G().p.hp===48,G().p.hp);

  // 4) 무기가 없으면 추첨 안 함
  G().w={};const n0=G().tierN;ok("무기 없음 → null",D.rollTier()===null&&G().tierN===n0);

  // 5) 배율 — 개수는 그대로, 피해만 ×1.5
  G().w={dart:3};G().lvls.dart=3;G().evo={};G().tier={};G().bul=[];G().cd.dart=0;D.weapons(0.0001);
  const base=G().bul.map(x=>x.dmg),nb=G().bul.length;
  G().tier={dart:3};G().bul=[];G().cd.dart=0;D.weapons(0.0001);
  const up=G().bul.map(x=>x.dmg);
  ok("탄 개수 동일",up.length===nb,[nb,up.length]);
  ok("피해 ×1.5",Math.abs(up[0]/base[0]-1.5)<1e-9,[base[0],up[0]]);
  ok("wstat 반영",D.wstat("dart",3).피해===Math.round((11+15)*G().st.dmg*1.5),D.wstat("dart",3));

  // 6) 이어하기 — 등급과 추첨 위치가 이어진다
  G().w={dart:1,blade:1};G().t=30;
  D.resetSeed();G().tierN=0;D.rollTier();D.rollTier();       // tierN=4
  G().tier={blade:2};                                         // 굴린 뒤에 고정 — 추첨이 blade를 올렸을 수 있다
  const expect=(()=>{D.resetSeed();for(let i=0;i<4;i++)D.R.tier();return D.R.tier();})();
  D.resetSeed();for(let i=0;i<4;i++)D.R.tier();             // 저장 직전 상태 재현
  D.saveRun();D.contRun();
  ok("복원 후 등급 유지",G().tier.blade===2,G().tier);
  ok("복원 후 추첨 위치 이어짐",D.R.tier()===expect);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
