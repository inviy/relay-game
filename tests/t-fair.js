(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G,p=G.p;
  /* 적 탄은 기체 위에 그린다 — 기체 중앙에 놓은 탄의 흰 코어가 보여야 한다 */
  G.eb.length=0;G.eb.push({x:p.x,y:p.y,vx:0,vy:0,r:8,dmg:0,life:9});D.draw();
  const cv=document.querySelector("canvas"),
    px=cv.getContext("2d").getImageData(cv.width/2|0,cv.height/2|0,1,1).data;
  ok("기체 중앙에 적 탄 흰 코어",px[0]>250&&px[1]>250&&px[2]>250,[...px]);
  /* 탄 판정 코어 6 — 몸통(13)이었다면 거리 15의 탄(r 6)에 맞았다 */
  const shot=d=>{G.en.length=0;G.eb.length=0;p.inv=0;p.hp=p.mhp;
    G.eb.push({x:p.x+d,y:p.y,vx:0,vy:0,r:6,dmg:10,life:9});D.update(1/60);return p.mhp-p.hp;};
  ok("거리 15 — 비켜 간다",shot(15)===0);
  ok("거리 10 — 맞는다",shot(10)>0);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
