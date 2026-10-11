(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G,p=G.p;
  ok("10:00 전에는 0",D.dkAt(1319)===0&&D.dkAt(0)===0);
  ok("15:00에 1, 넘어도 1",D.dkAt(1980)===1&&D.dkAt(5000)===1);
  const shooter=eth=>{G.en.length=0;G.eb.length=0;G.eth=eth;
    const e=D.makeE("shooter",p.x+250,p.y);e.fire=0;G.en.push(e);D.enemies(.001);return [G.eb.length,e.fire];};
  let r=shooter(0);ok("사수 기본 1발 · 2.3초",r[0]===1&&Math.abs(r[1]-2.3)<1e-9,r);
  r=shooter(1650);ok("dk .5 → 3갈래",r[0]===3,r);
  r=shooter(1980);ok("dk 1 → 5갈래 · 1.38초",r[0]===5&&Math.abs(r[1]-1.38)<1e-9,r);
  const ring=(eth,boss)=>{G.en.length=0;G.eb.length=0;G.eth=eth;G.dkT=0;G.boss=boss||null;
    G.en.push(D.makeE("wisp",p.x+200,p.y));D.danmaku(.001);const n=G.eb.length,t=G.dkT;G.boss=null;return [n,t];};
  r=ring(1000);ok("10:00 전 고리 없음",r[0]===0,r);
  r=ring(1980);ok("dk 1 고리 20발 · 1.6초",r[0]===20&&Math.abs(r[1]-1.6)<1e-9,r);
  r=ring(1980,{x:0,y:0});ok("보스 중엔 주기 2배",r[0]===20&&Math.abs(r[1]-3.2)<1e-9,r);
  G.en.length=0;G.eb.length=0;G.eth=1980;G.dkT=0;G.en.push(D.makeE("wisp",p.x+900,p.y));D.danmaku(.001);
  ok("화면 밖 적은 안 쏜다",G.eb.length===0);
  G.en.length=0;G.en.push(D.makeE("wisp",p.x+200,p.y));
  for(let i=0;i<D.EB_CAP;i++)G.eb.push({x:1e5,y:1e5,vx:0,vy:0,r:6,dmg:1,life:9});
  G.dkT=0;D.danmaku(.001);ok("상한 240에서 멈춤",G.eb.length===D.EB_CAP);
  /* 실전 — 12분에서 20초를 돌린다. 죽지 않게 체력만 크게 */
  G.en.length=0;G.eb.length=0;G.t=720;p.hp=p.mhp=1e9;let mx=0;
  for(let i=0;i<1200;i++){D.update(1/60);mx=Math.max(mx,G.eb.length);if(D.mode!=="play")break;}
  ok("12분 실전 20초 — 예외 없음, 적 탄 발생",mx>0,{maxEb:mx,en:G.en.length});
  /* 그리기 비용 — 적 탄 0 vs 240 */
  const bench=n=>{G.eb.length=0;for(let i=0;i<n;i++){const g=i/n*6.283,d=60+i%8*40;
      G.eb.push({x:p.x+Math.cos(g)*d,y:p.y+Math.sin(g)*d,vx:0,vy:0,r:6,dmg:1,life:9});}
    D.draw();const t=performance.now();for(let i=0;i<60;i++)D.draw();return (performance.now()-t)/60;};
  const a=bench(0),b=bench(240);
  ok("240발 그리기 추가 비용 < 4ms",b-a<4,{ms0:+a.toFixed(2),ms240:+b.toFixed(2)});
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
