(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  D.PAID.fast=0;D.start();const G=D.G;
  let t=performance.now();D.loop(t);const g0=G.t;D.loop(t+40);const a=G.t-g0;
  D.PAID.fast=1;const g1=G.t;D.loop(t+80);const b=G.t-g1;
  ok("1.5배로 흐른다",Math.abs(b/a-1.5)<1e-6,[a,b]);
  ok("fastUsed 기록",G.fastUsed===true);
  D.PAID.fast=1;const g2=G.t;D.loop(t+80+500);const c=G.t-g2;
  ok("상한 뒤에 곱함 (.05×1.5)",Math.abs(c-.075)<1e-6,c);

  D.mode="menu";D.showVeil("#v-menu");D.PAID.fast=0;
  const nick=document.getElementById("nick");nick.focus();
  nick.dispatchEvent(new KeyboardEvent("keydown",{key:"f",bubbles:true}));
  ok("이름 칸 f 무시",D.PAID.fast===0);nick.blur();
  dispatchEvent(new KeyboardEvent("keydown",{key:"f",ctrlKey:true}));
  ok("Ctrl+F 무시",D.PAID.fast===0);
  dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));
  ok("F 토글",D.PAID.fast===1);
  dispatchEvent(new KeyboardEvent("keydown",{key:"u"}));
  ok("U 토글",D.PAID.auto===1);D.PAID.auto=0;
  dispatchEvent(new KeyboardEvent("keydown",{key:"u",repeat:true}));
  ok("키 반복은 토글 안 함",D.PAID.auto===0);

  localStorage.removeItem("relay:master");D.PAID.fast=0;
  dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));
  ok("마스터 아니면 F 무반응",D.PAID.fast===0);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
