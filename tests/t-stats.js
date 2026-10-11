(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));localStorage.removeItem("relay:hist");
  for(let i=0;i<31;i++){D.start();const G=D.G;G.t=30+i;G.dmgBy={dart:100+i,blade:50,chain:10};G.autoUsed=i%2===0;D.finish(false);}
  const h=JSON.parse(localStorage.getItem("relay:hist"));
  ok("30판만 유지",h.length===30,h.length);
  ok("가장 오래된 게 빠짐",h.every(r=>r.t>=31),h.map(r=>r.t).slice(-3));
  ok("상위 무기 3개",JSON.stringify(h[0].top)===JSON.stringify(["dart","blade","chain"]),h[0].top);
  ok("AUTO 표시 저장",typeof h[0].a==="boolean");
  D.openStats();ok("목록 30줄",document.querySelectorAll("#statlist .sr").length===30);
  ok("최고 빌드 표시",/최고 빌드/.test(document.getElementById("v-stats").textContent));
  localStorage.removeItem("relay:master");D.openStats();
  ok("마스터 아니면 잠김",/유료 · 준비 중/.test(document.getElementById("v-stats").textContent));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
