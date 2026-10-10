(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;const want=innerWidth>=1200;
  ok("bigPC 판정",D.bigPC()===(want&&matchMedia("(pointer: fine)").matches),{w:innerWidth,fine:matchMedia("(pointer: fine)").matches,bigPC:D.bigPC()});
  ok("body.bigpc",document.body.classList.contains("bigpc")===D.bigPC());
  G.w={dart:2,blade:1};G.lvls.dart=2;G.lvls.blade=1;G.tier={dart:3};G.dmgBy={dart:300,blade:100};
  for(let i=0;i<30;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
  const P=document.getElementById("wpanel");
  if(D.bigPC()){
    ok("패널 보임",getComputedStyle(P).display!=="none");
    ok("패널에 무기 2줄",P.querySelectorAll(".wp").length===2,P.innerHTML.length);
  }else ok("패널 숨김",getComputedStyle(P).display==="none");
  D.finish(false);const B=document.getElementById("dmgbars");
  ok("결과 피해 분석",D.bigPC()?B.children.length===2:B.innerHTML==="",B.innerHTML.slice(0,80));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
