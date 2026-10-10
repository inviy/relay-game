(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg,cv=document.getElementById("cv"),c2=cv.getContext("2d");
  // 플레이어 중심 480×480 창의 평균 밝기
  const lum=()=>{const S=480,x0=Math.max(0,(cv.width-S>>1)),y0=Math.max(0,(cv.height-S>>1)),w=Math.min(S,cv.width),h=Math.min(S,cv.height);
    const d=c2.getImageData(x0,y0,w,h).data;let s=0,n=0;for(let i=0;i<d.length;i+=16){s+=(d[i]+d[i+1]+d[i+2])/3;n++;}return s/n;};
  const spread=L=>{const dl=L.slice(1).map((v,i)=>Math.abs(v-L[i])),avg=dl.reduce((a,b)=>a+b,0)/dl.length,mx=Math.max(...dl);return{avg:+avg.toFixed(2),max:+mx.toFixed(2),spread:+(mx-avg).toFixed(2)};};
  const run=(act)=>{D.start();const G=D.G;for(let i=0;i<300;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
    const L=[];for(let f=0;f<60;f++){if(f%10===0)act(G,f);D.update(1/60);if(D.mode!=="play")D.mode="play";D.draw();L.push(lum());}return spread(L);};
  const tiers=[1,2,3,4];
  const chest=run((G,f)=>{const t=tiers[(f/10)%4];D.TIERS.forEach((x,i)=>x.p=i===t-1?1:0);G.w={dart:1,blade:1,chain:1};G.tier={};
    D.openChest({x:G.p.x,y:G.p.y,type:"chest"});if(D.mode==="reveal")D.closeReveal();});
  const bomb=run((G,f)=>{if(f===0||f===30)G.items.push({x:G.p.x,y:G.p.y,type:"bomb",ph:0});});
  ok("상자 깜빡임 ≤ 0.5 × 폭탄",chest.spread<=bomb.spread*.5,{chest,bomb});
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
