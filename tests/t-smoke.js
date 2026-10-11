(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();
  for(let i=0;i<600;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
  ok("시간이 흐른다",D.G.t>9.9,D.G.t);
  ok("무기가 있다",Object.keys(D.G.w).length>=1,Object.keys(D.G.w));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
