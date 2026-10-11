(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));D.PAID.auto=1;D.start();const G=D.G,p=G.p;
  /* 정면으로 날아오는 탄 다섯 줄기 — 뒤로 물러나면 따라 맞는다. 옆으로 비켜야 산다 */
  let hit=0;
  for(let r=0;r<20;r++){G.en.length=0;G.eb.length=0;G.items.length=0;G.zone.x=p.x;G.zone.y=p.y;p.inv=0;p.hp=p.mhp;G.autoDir=null;
    const a=r/20*6.283;for(let j=-2;j<=2;j++){const g=a+j*.05;
      G.eb.push({x:p.x+Math.cos(a)*260+Math.cos(a+1.57)*j*14,y:p.y+Math.sin(a)*260+Math.sin(a+1.57)*j*14,vx:-Math.cos(a)*300,vy:-Math.sin(a)*300,r:7,dmg:10,life:3});}
    for(let i=0;i<180;i++)D.update(1/60);if(p.hp<p.mhp)hit++;}
  ok("정면 탄막 20회 중 맞은 횟수 ≤ 2",hit<=2,hit);
  /* 비용 — 적 탄 240발 · 적 120마리에서 한 번 판단하는 데 드는 시간 */
  G.eb.length=0;G.en.length=0;for(let i=0;i<240;i++){const g=i/240*6.283,d=80+i%6*60;
    G.eb.push({x:p.x+Math.cos(g)*d,y:p.y+Math.sin(g)*d,vx:-Math.cos(g)*150,vy:-Math.sin(g)*150,r:6,dmg:1,life:9});}
  for(let i=0;i<120;i++)G.en.push(D.makeE("wisp",p.x+Math.cos(i)*(60+i*2),p.y+Math.sin(i)*(60+i*2)));
  const t0=performance.now();for(let i=0;i<100;i++)D.autoSteer();const ms=(performance.now()-t0)/100;
  ok("판단 1회 < 2ms (240발 · 120마리)",ms<2,+ms.toFixed(3));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";document.getElementById("out").textContent=JSON.stringify(out);})();
