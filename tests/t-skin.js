(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  D.PAID.skin="base";ok("기본은 그대로","#4ff0d8"===D.skinC("#4ff0d8"));
  D.PAID.skin="neon";ok("네온은 바뀜",D.skinC("#4ff0d8")!=="#4ff0d8",D.skinC("#4ff0d8"));
  ok("등급 색은 표에 없음",D.TIERS.every(t=>D.skinC(t.c)===t.c));
  localStorage.removeItem("relay:master");ok("마스터 아니면 기본",D.skinC("#4ff0d8")==="#4ff0d8");
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
