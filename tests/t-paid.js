(async()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;
  localStorage.removeItem("relay:master");
  ok("기본은 마스터 아님",D.isMaster()===false);
  D.PAID.auto=1;ok("마스터 아니면 paidOn false",D.paidOn("auto")===false);
  D.openPaid();
  ok("잠금 표시",/유료 · 준비 중/.test(document.getElementById("v-paid").textContent));
  const tg=document.querySelector("#v-paid [data-k=fast]");tg.click();
  ok("잠긴 토글은 안 바뀜",D.PAID.fast===0,D.PAID.fast);

  localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  ok("해시가 맞으면 마스터",D.isMaster()===true);
  ok("paidOn true",D.paidOn("auto")===true);
  D.openPaid();document.querySelector("#v-paid [data-k=fast]").click();
  ok("마스터는 토글됨",D.PAID.fast===1);
  ok("저장됨",JSON.parse(localStorage.getItem("relay:paid")).fast===1);

  localStorage.setItem("relay:master",JSON.stringify("deadbeef"));
  ok("틀린 해시는 마스터 아님",D.isMaster()===false);

  // URL 코드 처리 — 틀린 코드는 저장 안 함
  localStorage.removeItem("relay:master");
  history.replaceState(null,"","?master=wrong");await D.checkMaster();
  ok("틀린 코드 무시",D.isMaster()===false);
  ok("파라미터 제거",!/master=/.test(location.search),location.search);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
