(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();
  const G=D.G;
  const run=w=>{G.w=w;Object.keys(w).forEach(k=>G.lvls[k]=2);
    for(let i=0;i<1800;i++){G.p.hp=G.p.mhp;D.update(1/60);if(D.mode!=="play")D.mode="play";}};
  // 원거리가 근접 무기보다 먼저 적을 죽이므로 두 번으로 나눠 돌린다
  run({dart:2,bolt:2});run({blade:2,flame:2});
  const s=G.dmgBy||{};
  ["dart","blade","flame","bolt"].forEach(k=>ok(k+" 집계됨",s[k]>0,s[k]));
  const total=Object.values(s).reduce((a,b)=>a+b,0);
  ok("무기 아닌 키 없음",Object.keys(s).every(k=>k in D.WEAPONS),Object.keys(s));
  ok("합계 양수",total>0,Math.round(total));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
