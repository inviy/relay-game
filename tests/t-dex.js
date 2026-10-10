(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.removeItem("relay:dex");D.start();const G=D.G;
  ok("처음엔 0",D.dexCount()===0);
  ok("첫 등록은 새 칸",D.dexAdd("dart",2)===true);
  ok("같은 칸은 새 칸 아님",D.dexAdd("dart",2)===false);
  ok("저장됨",!!JSON.parse(localStorage.getItem("relay:dex"))["dart:2"]);
  ok("카운트 1",D.dexCount()===1);
  ok("판 내 신규 수",G.dexNew===1,G.dexNew);

  // 메뉴 링크와 D 키
  D.mode="menu";D.menu();D.showVeil("#v-menu");
  ok("메뉴 링크 n/40",/1\/40/.test(document.getElementById("dexlink").textContent),document.getElementById("dexlink").textContent);
  dispatchEvent(new KeyboardEvent("keydown",{key:"d"}));
  ok("메뉴에서 D → 도감",!document.getElementById("v-dex").classList.contains("off"));
  D.showVeil("#v-menu");
  const nick=document.getElementById("nick");nick.focus();
  nick.dispatchEvent(new KeyboardEvent("keydown",{key:"d",bubbles:true}));
  ok("이름 입력 중 D는 무시",document.getElementById("v-dex").classList.contains("off"));
  nick.blur();

  // 격자 40칸
  D.openDex();ok("격자 40칸",document.querySelectorAll("#dexgrid .dc").length===40);

  // 결과 화면 줄과 공유 문구
  D.start();D.G.dexNew=2;D.G.tierBest=4;D.G.tier={chain:4};D.finish(false);
  ok("결과에 도감 줄",/도감 \+2/.test(document.getElementById("dexline").textContent),document.getElementById("dexline").textContent);
  ok("공유에 신화 줄",/신화 · 연쇄 번개/.test(D.shareText()),D.shareText());
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
