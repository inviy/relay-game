(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{const D=window.__dbg;D.PAID.auto=0;D.start();const G=D.G;
  /* 레벨업 화면에서 이동키는 아무것도 고르지 않는다 — S가 건너뛰기였다 */
  G.p.xp=G.p.need;D.gainXp(0.01);ok("레벨업 화면 뜸",D.mode==="level");
  for(const key of ["w","a","s","d","ArrowUp","ArrowDown","ArrowLeft","ArrowRight"]){
    dispatchEvent(new KeyboardEvent("keydown",{key}));dispatchEvent(new KeyboardEvent("keyup",{key}));}
  ok("이동키로는 안 닫힌다",D.mode==="level",D.mode);
  dispatchEvent(new KeyboardEvent("keydown",{key:"1"}));
  ok("숫자 키로 고른다",D.mode!=="level",D.mode);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";document.getElementById("out").textContent=JSON.stringify(out);})();
