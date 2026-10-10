(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;let c3=null;
  for(let i=0;i<660*30;i++){
    G.p.hp=G.p.mhp;D.update(1/30);
    if(G.t>=180&&c3===null)c3=G.chestN;
    if(D.mode!=="play"){const b=document.querySelector(".veil:not(.off) .card");if(b)b.click();else D.mode="play";}
    if(G.over||G.dying>0)break;}
  const lvcap=10+Math.floor(Math.log(Math.max(G.kills,1)+1)*4)+Math.floor(G.t/18);
  const pm=1-Math.pow(1-D.TIERS[3].p,G.chestN);
  ok("측정",true,{t:Math.round(G.t),chest:G.chestN,chest3m:c3,tier:G.tier,lv:G.p.lv,lvcap,kills:G.kills,pMythFull:+pm.toFixed(2)});
  ok("3분 안에 상자 1개 이상",c3>=1,c3);
  ok("서버 레벨 상한 통과",G.p.lv<=lvcap,[G.p.lv,lvcap]);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
