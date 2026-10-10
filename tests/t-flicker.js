(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G,cv=document.getElementById("cv"),c2=cv.getContext("2d");
  const lum=()=>{const d=c2.getImageData(0,0,cv.width,cv.height).data,sx=Math.floor(cv.width/64),sy=Math.floor(cv.height/64);let s=0,n=0;
    for(let y=0;y<cv.height;y+=sy)for(let x=0;x<cv.width;x+=sx){const i=(y*cv.width+x)*4;s+=(d[i]+d[i+1]+d[i+2])/3;n++;}return s/n;};
  for(let i=0;i<300;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
  D.TIERS.forEach((x,i)=>x.p=i===0?1:0);
  const L=[];
  for(let f=0;f<60;f++){
    if(f%12===0){G.w={dart:1,blade:1,chain:1};G.tier={};D.openChest({x:G.p.x,y:G.p.y,type:"chest"});}
    D.update(1/60);if(D.mode!=="play")D.mode="play";D.draw();L.push(lum());}
  const dl=L.slice(1).map((v,i)=>Math.abs(v-L[i])),avg=dl.reduce((a,b)=>a+b,0)/dl.length,mx=Math.max(...dl);
  ok("깜빡임 변동폭 ≤ 12 (기준 8.0)",mx-avg<=12,{avg:+avg.toFixed(1),max:+mx.toFixed(1),spread:+(mx-avg).toFixed(1)});
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
