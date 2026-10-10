(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;let c3=null;
  for(let i=0;i<660*30;i++){
    G.p.hp=G.p.mhp;
    let c=null,cd=1e18;for(const it of G.items)if(it.type==="chest"){const d=Math.hypot(it.x-G.p.x,it.y-G.p.y);if(d<cd){cd=d;c=it;}}
    if(c){const dx=c.x-G.p.x,dy=c.y-G.p.y,l=Math.hypot(dx,dy)||1,s=Math.min(l,G.p.spd/30);G.p.x+=dx/l*s;G.p.y+=dy/l*s;}
    D.update(1/30);
    if(G.t>=180&&c3===null)c3=G.chestN;
    if(D.mode!=="play"){const b=document.querySelector(".veil:not(.off) .card");if(b)b.click();else D.mode="play";}
    if(G.over||G.dying>0)break;}
  const lvcap=10+Math.floor(Math.log(Math.max(G.kills,1)+1)*4)+Math.floor(G.t/18);
  const pm=1-Math.pow(1-D.TIERS[3].p,G.chestN);
  ok("측정",true,{t:Math.round(G.t),chest:G.chestN,chest3m:c3,tier:G.tier,lv:G.p.lv,lvcap,kills:G.kills,pMythFull:+pm.toFixed(2)});
  ok("3분 안에 상자 1개 이상",c3>=1,c3);
  ok("서버 레벨 상한 (정보 — 기존 동작)",true,[G.p.lv,lvcap]);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
