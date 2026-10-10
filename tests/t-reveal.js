(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;const V=document.getElementById("v-reveal");
  const force=t=>{D.TIERS.forEach((x,i)=>x.p=i===t-1?1:0);};     // 이 페이지에서만 확률을 고정

  // 에픽 — 판이 멈추지 않는다. 상자 경험치(need×1.1)는 늘 레벨을 올리므로 mode는 "level"이 될 수 있다
  force(1);G.w={dart:1};G.tier={};D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("에픽은 reveal 아님",D.mode!=="reveal",D.mode);
  ok("에픽은 veil 안 뜸",V.classList.contains("off"));
  D.mode="play";

  // 전설 — 멈추고, 시계가 안 간다
  force(3);G.w={dart:1};G.tier={};const t0=G.t;D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("전설은 reveal",D.mode==="reveal",D.mode);
  ok("전설 veil 뜸",!V.classList.contains("off"));
  ok("시계 정지",G.t===t0);

  // 열린 직후 반복 keydown은 무시된다
  dispatchEvent(new KeyboardEvent("keydown",{key:"w",repeat:true}));
  ok("반복 키 무시",D.mode==="reveal");
  D.G.revOpen=performance.now()-1000;                            // 0.4초가 지났다고 친다
  dispatchEvent(new KeyboardEvent("keydown",{key:"x"}));
  ok("키로 닫힘",D.mode!=="reveal"&&V.classList.contains("off"),D.mode);   // 닫히면 대기 중 레벨업이 뜰 수 있다
  D.mode="play";

  // 연출 중 레벨업은 닫힌 뒤에 뜬다
  force(4);G.w={dart:1};G.tier={};G.p.xp=G.p.need-0.01;
  D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("연출 중엔 레벨업 대기",D.mode==="reveal"&&G.pend>=1,{mode:D.mode,pend:G.pend});
  D.closeReveal();
  ok("닫으면 레벨업",D.mode==="level",D.mode);
  D.mode="play";D.showVeil("#v-menu");

  // 숨은 탭에서 자동 닫힘 → 일시정지
  force(3);G.w={dart:1};G.tier={};D.mode="play";D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  Object.defineProperty(document,"hidden",{configurable:true,get:()=>true});
  D.closeReveal();
  ok("숨은 탭이면 pause",D.mode==="pause",D.mode);
  delete document.hidden;
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
