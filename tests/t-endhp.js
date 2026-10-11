(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;
  const HPM=[.9,1,1.05,1.1,1.2,1.3,2.2];   // 사도 14기의 hpM 전부
  const hp=(n,ended)=>{G.bosses=n;G.ended=ended;G.boss=null;D.spawnBoss();return {hp:G.boss.mhp,fin:G.boss.fin,ang:G.boss.ang};};
  const isOld=(r,n)=>HPM.some(m=>Math.abs(r.hp/(9000*Math.pow(1.55,n)*m)-1)<1e-4);
  for(const n of [0,3,5]){const r=hp(n,false);ok("본편 "+n+"번째 1.55배 그대로",isOld(r,n),r);}
  const f=hp(6,false);
  ok("종단 체력 불변",f.fin===1&&f.hp===Math.round(9000*Math.pow(1.55,6)*2.4),f);
  const a7=hp(7,true);
  ok("무한 첫 사도 불변",isOld(a7,7),a7);
  /* 무한 로스터는 7기 — n과 n+7은 같은 사도라 hpM이 지워지고 비율이 정확히 1.2^7 */
  const a14=hp(14,true);
  ok("한 바퀴 뒤 같은 사도",a14.ang===a7.ang,[a7.ang,a14.ang]);
  ok("무한은 한 기에 1.2배",Math.abs(a14.hp/a7.hp-Math.pow(1.2,7))<1e-4,a14.hp/a7.hp);
  const a13=hp(13,true);
  ok("무한 7번째 사도 120만 이하 (예전 최소 200만)",a13.hp<1.2e6,a13);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
