# 유료 기능 1차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 마스터만 켤 수 있는 유료 기능 네 가지 — AUTO(순위 제외), 1.5배속(순위 유지), 연출 스킨, 상세 통계 — 를 넣는다.

**Architecture:** 단일 파일 `index.html`의 IIFE 안에 넣는다. 권한은 `isMaster()`, 설정은 `PAID` 객체(`relay:paid`), 기능 게이트는 `paidOn(k)`. AUTO 이동은 `update()`의 이동 입력 자리, AUTO 선택은 `showVeil("#v-level")` 시점의 타이머, 배속은 `loop()`의 `dt`, 순위 제외는 `submitScore`/`submitBeacon` 입구에서 막는다.

**Tech Stack:** 바닐라 JS + Canvas 2D + CSS, Web Crypto(`crypto.subtle.digest`), 헤드리스 Chrome 하네스(`tests/probe.mjs`).

**Spec:** `docs/superpowers/specs/2026-10-11-paid-features-design.md`

## Global Constraints

- `MASTER_H="f7bd7c632bf94f3bb0fae013a39cf098ec7499aadc49086f5e7ddbfa0653238d"` (코드 원문은 소스·테스트·커밋 어디에도 넣지 않는다. 테스트는 `D.setMasterHash()` 같은 우회 대신 `localStorage`에 해시를 직접 넣어 마스터 상태를 만든다)
- 저장 키: `relay:master`(해시 문자열), `relay:paid`(`{auto,fast,skin}`), `relay:hist`(최근 30판 배열)
- AUTO를 켠 판은 `submit_score` 요청 0건. 1.5배속 판은 정상 제출.
- 배속: `dt=Math.min(.05,…)` **뒤에** `×1.5`
- 스킨은 탄·검 색만. `TIERS[*].c`와 등급 shadowColor는 그대로.
- 서버·SQL 변경 없음.
- 버전 `VERSION="3.9.0"`.
- 커밋 트레일러 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **이름 칸에서 `u`·`f` 입력** — 글자가 들어가야 한다. AUTO·배속이 토글되면 안 된다(입력 요소 무시, Ctrl/Cmd/Alt 무시). → Task 2 테스트
2. **AUTO 판의 이탈 제출** — 탭을 숨기면 `leave()`가 `submitBeacon()`을 부른다. 여기서도 제출되면 안 된다. → Task 3 테스트
3. **사람 입력 우선** — AUTO가 켜져 있어도 키를 누르면 사람 방향으로 간다. → Task 3 테스트
4. **AUTO 자동 선택이 이미 닫힌 화면을 누름** — 0.6초 안에 사람이 먼저 고르면 타이머는 아무것도 하지 않아야 한다(mode가 바뀌었거나 카드가 사라짐). → Task 3 테스트
5. **이어하기** — AUTO 판을 저장·복원하면 여전히 순위 제외다(`autoUsed`가 RUNF에). → Task 3 테스트

---

### Task 1: 마스터 권한 · 설정 · 유료 기능 화면

**Files:** Modify `index.html` (`const ls` 근처, 메뉴 마크업 `#dexlink` 다음, `#v-dex` 뒤, CSS, `showVeil`/`hideAll` 배열, `menu()`); Modify `tests/hook.js`; Create `tests/t-paid.js`

**Interfaces:**
- Produces: `MASTER_H`, `isMaster():boolean`, `PAID:{auto:0|1,fast:0|1,skin:string}`, `savePaid():void`, `paidOn(k:"auto"|"fast"):boolean`(= 마스터 && PAID[k]), `checkMaster():Promise<void>`(URL `?master=` 처리), `openPaid():void`, `#v-paid`

- [ ] **Step 1: 실패하는 테스트** `tests/t-paid.js`
```js
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
```
하네스는 동기 결과를 가정하지만 `--virtual-time-budget`이 프로미스를 기다려 준다. `#out`을 마지막에 쓰므로 문제없다.

`tests/hook.js` 끝 `…,bigPC};`를 `…,bigPC,MASTER_H,isMaster,PAID,savePaid,paidOn,checkMaster,openPaid};`로 바꾼다.

- [ ] **Step 2:** `node tests/probe.mjs tests/t-paid.js` → NO OUTPUT(훅 이름 없음)

- [ ] **Step 3: 구현** — `const DKEY="relay:dex";` 바로 위에 추가:
```js
/* ───── 유료 기능 ─────
   결제는 아직 없다. 마스터(본인)만 무료로 켠다. 소스에는 코드의 해시만 둔다 —
   단일 파일이라 localStorage를 고치면 누구나 켤 수 있다는 건 알고 간다. AUTO 판은
   순위에 오르지 않으니 뚫려도 순위는 안전하다. 결제를 붙일 때 서버 검증으로 바꾼다 */
const MASTER_H="f7bd7c632bf94f3bb0fae013a39cf098ec7499aadc49086f5e7ddbfa0653238d";
const isMaster=()=>ls.get("relay:master","")===MASTER_H;
const PAID=Object.assign({auto:0,fast:0,skin:"base"},ls.get("relay:paid",{}));
const savePaid=()=>ls.set("relay:paid",PAID);
const paidOn=k=>isMaster()&&!!PAID[k];
async function checkMaster(){const q=new URLSearchParams(location.search),c=q.get("master");
  if(c===null)return;
  try{const h=[...new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(c)))]
      .map(b=>b.toString(16).padStart(2,"0")).join("");
    if(h===MASTER_H){ls.set("relay:master",h);}}catch(e){}
  q.delete("master");history.replaceState(null,"",location.pathname+(q.toString()?"?"+q:"")+location.hash);}
```
파일 끝 초기화 구역(`$("#ver").textContent="v"+VERSION;` 근처)에 `checkMaster().then(()=>{try{menu();}catch(e){}});` 추가.

마크업 — `#dexlink` 줄 다음:
```html
  <p id="paidlink" style="margin:4px 0 0;font-size:13.5px;color:var(--ash);cursor:pointer">유료 기능</p>
```
`#v-dex` 블록 뒤:
```html
<div class="veil off" id="v-paid"><div class="box">
  <div class="tag">유료 기능</div>
  <h2 style="margin-top:10px">편하게, 다르게</h2>
  <div id="paidlist"></div>
  <button class="btn ghost" id="b-paidclose" style="margin-top:18px">닫기</button>
</div></div>
```
CSS(`#dexgrid` 규칙 뒤):
```css
#paidlist{max-width:420px;margin:16px auto 0;text-align:left}
#paidlist .pr{display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid var(--line);border-radius:3px;margin:6px 0;cursor:pointer;color:var(--pale)}
#paidlist .pr.on{border-color:var(--gold);color:var(--gold)}
#paidlist .pr.lock{opacity:.55;cursor:not-allowed}
#paidlist .pr small{margin-left:auto;color:var(--ash)}
```
`showVeil`·`hideAll` 배열에 `"#v-paid"` 추가. 함수(`openDex` 위):
```js
function openPaid(){const m=isMaster(),SK={base:"기본",neon:"네온",plat:"백금"};
  const row=(k,t,on,sub)=>`<div class="pr${m?(on?" on":""):" lock"}" data-k="${k}">${t}<small>${m?sub:"🔒 유료 · 준비 중"}</small></div>`;
  $("#paidlist").innerHTML=
    row("auto","AUTO — 이동·선택 자동",PAID.auto,PAID.auto?"켜짐 · 순위 제외":"꺼짐")+
    row("fast","1.5배속",PAID.fast,PAID.fast?"켜짐":"꺼짐")+
    row("skin","연출 스킨 — "+SK[PAID.skin],PAID.skin!=="base","누르면 바뀜")+
    row("stats","기록 보기",0,"최근 30판");
  $("#paidlist").querySelectorAll(".pr").forEach(el=>el.onclick=()=>{if(!isMaster())return;const k=el.dataset.k;
    if(k==="auto"||k==="fast"){PAID[k]=PAID[k]?0:1;savePaid();openPaid();}
    else if(k==="skin"){const o=["base","neon","plat"];PAID.skin=o[(o.indexOf(PAID.skin)+1)%3];savePaid();openPaid();}
    else if(k==="stats"&&typeof openStats==="function")openStats();});
  showVeil("#v-paid");}
$("#paidlink").onclick=openPaid;
$("#b-paidclose").onclick=()=>showVeil("#v-menu");
```

- [ ] **Step 4:** `node tests/probe.mjs tests/t-paid.js` → 전부 PASS. `t-dex`, `t-smoke`도 PASS.
- [ ] **Step 5:** 커밋 `feat: 유료 기능 화면과 마스터 권한`

---

### Task 2: 1.5배속 · HUD 버튼 · 단축키

**Files:** Modify `index.html` (`loop()`, HUD 마크업 `#pausebtn` 근처, CSS, keydown, `newRun()`·`RUNF`, `track("end",…)`); Modify `tests/hook.js`; Create `tests/t-fast.js`

**Interfaces:**
- Consumes: `paidOn`, `PAID`, `savePaid`, `isMaster`
- Produces: `G.fastUsed:boolean`, `paidBar():void`(HUD 버튼 표시 갱신), 키 `U`(PAID.auto 토글), `F`(PAID.fast 토글)

- [ ] **Step 1: 테스트** `tests/t-fast.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  D.PAID.fast=0;D.start();const G=D.G;
  let t=performance.now();D.loop(t);const g0=G.t;D.loop(t+40);const a=G.t-g0;   // 40ms → .04
  D.PAID.fast=1;const g1=G.t;D.loop(t+80);const b=G.t-g1;
  ok("1.5배로 흐른다",Math.abs(b/a-1.5)<1e-6,[a,b]);
  ok("fastUsed 기록",G.fastUsed===true);
  D.PAID.fast=1;const g2=G.t;D.loop(t+80+500);const c=G.t-g2;
  ok("상한 뒤에 곱함 (.05×1.5)",Math.abs(c-.075)<1e-6,c);

  // 키: 입력 칸·조합키 무시
  D.mode="menu";D.showVeil("#v-menu");D.PAID.fast=0;
  const nick=document.getElementById("nick");nick.focus();
  nick.dispatchEvent(new KeyboardEvent("keydown",{key:"f",bubbles:true}));
  ok("이름 칸 f 무시",D.PAID.fast===0);nick.blur();
  dispatchEvent(new KeyboardEvent("keydown",{key:"f",ctrlKey:true}));
  ok("Ctrl+F 무시",D.PAID.fast===0);
  dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));
  ok("F 토글",D.PAID.fast===1);
  dispatchEvent(new KeyboardEvent("keydown",{key:"u"}));
  ok("U 토글",D.PAID.auto===1);D.PAID.auto=0;

  localStorage.removeItem("relay:master");D.PAID.fast=0;
  dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));
  ok("마스터 아니면 F 무반응",D.PAID.fast===0);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
`tests/hook.js`에 `paidBar` 추가.

- [ ] **Step 2:** 실패 확인
- [ ] **Step 3: 구현**
  - `loop()`: `let dt=Math.min(.05,(now-last)/1000);last=now;` 다음 줄에
    ```js
    if(paidOn("fast")){dt*=1.5;G.fastUsed=true;}   // 상한 뒤에 곱한다 — 순위 유지, 서버는 게임 시간만 본다
    ```
  - `newRun()`의 `dexNew:0,` 뒤에 `autoUsed:false,fastUsed:false,` 추가. `RUNF` 끝에 `"autoUsed","fastUsed"` 추가.
  - `track("end",{…` 객체에 `auto:!!G.autoUsed,fast:!!G.fastUsed` 추가.
  - HUD: `#pausebtn` 버튼 바로 뒤에
    ```html
    <div id="paidbar"><button id="b-auto">AUTO</button><button id="b-fast">1.5×</button></div>
    ```
    CSS:
    ```css
    #paidbar{display:none;position:absolute;top:136px;right:16px;gap:10px;pointer-events:auto}
    body.master #paidbar{display:flex}
    #paidbar button{background:none;border:1px solid var(--line);border-radius:3px;color:var(--ash);font:inherit;font-size:12px;font-weight:600;letter-spacing:.12em;padding:4px 8px;cursor:pointer}
    #paidbar button.on{color:var(--gold);border-color:var(--gold)}
    ```
    모바일 미디어쿼리에서 `#pausebtn`의 top이 바뀌면 `#paidbar`도 그 아래로 맞춘다(같은 블록에 `#paidbar{top:calc(<pausebtn top> + 30px)}`).
  - 함수(`openPaid` 아래):
    ```js
    function paidBar(){document.body.classList.toggle("master",isMaster());
      $("#b-auto").classList.toggle("on",!!PAID.auto);$("#b-fast").classList.toggle("on",!!PAID.fast);}
    function togglePaid(k){if(!isMaster())return;PAID[k]=PAID[k]?0:1;savePaid();paidBar();
      call(k==="auto"?(PAID.auto?"AUTO 켜짐 — 이 판은 순위 제외":"AUTO 꺼짐"):(PAID.fast?"1.5배속":"보통 속도"));}
    $("#b-auto").onclick=()=>togglePaid("auto");$("#b-fast").onclick=()=>togglePaid("fast");
    ```
    `openPaid`의 auto/fast 토글 분기도 `togglePaid(k);openPaid();`로 바꾼다. 초기화 `checkMaster().then(…)` 안에서 `paidBar()`도 부른다.
  - keydown: `if(mode==="reveal"){…return;}` 다음 줄에
    ```js
    if(!e.ctrlKey&&!e.metaKey&&!e.altKey&&!/INPUT|SELECT|TEXTAREA/.test((e.target&&e.target.tagName)||"")){
      const k=e.key.toLowerCase();if(k==="u"||k==="f"){togglePaid(k==="u"?"auto":"fast");return;}}
    ```
    (메뉴의 `D` 처리보다 앞이어도 키가 달라 충돌 없음)
- [ ] **Step 4:** `t-fast`, `t-paid`, `t-reveal`, `t-dex`, `t-smoke` PASS
- [ ] **Step 5:** 커밋 `feat: 1.5배속과 유료 버튼 · 단축키`

---

### Task 3: AUTO — 이동 · 자동 선택 · 순위 제외

**Files:** Modify `index.html` (`update()` 이동 입력, `showVeil()`, `submitScore()`, `submitBeacon()`, `finish()`); Modify `tests/hook.js`; Create `tests/t-auto.js`

**Interfaces:**
- Consumes: `paidOn("auto")`, `G.autoUsed`, `near()`, `G.zone`, `G.items`, `G.en`, `G.eb`
- Produces: `autoSteer():[number,number]`, `autoPick():void`

- [ ] **Step 1: 테스트** `tests/t-auto.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  let sub=0;const f0=window.fetch;window.fetch=(u,o)=>{if(String(u).includes("submit_score"))sub++;return f0(u,o);};
  D.PAID.auto=1;D.PAID.fast=0;D.start();const G=D.G;
  const x0=G.p.x,y0=G.p.y;
  for(let i=0;i<60;i++)D.update(1/60);
  ok("AUTO가 움직인다",Math.hypot(G.p.x-x0,G.p.y-y0)>5,[G.p.x-x0,G.p.y-y0]);
  ok("autoUsed",G.autoUsed===true);

  // 사람 입력 우선
  const s=D.autoSteer();D.keys.d=1;const px=G.p.x;D.update(1/60);D.keys.d=0;
  ok("사람 입력 우선",G.p.x>px,[px,G.p.x,s]);

  // 자동 선택: 레벨업 화면을 0.6초 뒤 스스로 닫는다
  G.p.xp=G.p.need;D.gainXp(0.01);
  ok("레벨업 화면 뜸",D.mode==="level");
  D.autoPick();ok("autoPick이 고름",D.mode!=="level",D.mode);

  // 사람이 먼저 골랐으면 타이머는 아무것도 안 한다
  D.mode="play";D.autoPick();ok("화면 없으면 무동작",D.mode==="play");

  // 3분 생존(정보)
  let died=false;for(let i=0;i<180*30;i++){D.update(1/30);
    if(D.mode==="level"||D.mode==="reveal")D.autoPick(),D.mode==="reveal"&&D.closeReveal();
    if(G.dying>0||G.over){died=true;break;}}
  ok("3분 생존 (정보)",true,{t:Math.round(G.t),lv:G.p.lv,died,weapons:Object.keys(G.w).length});

  // 이어하기 후에도 순위 제외
  if(!G.over){G.t=Math.max(G.t,30);D.saveRun();D.contRun();}
  ok("복원 후 autoUsed 유지",D.G.autoUsed===true);
  D.PAID.auto=0;
  // 이탈 제출과 종료 제출 모두 0건
  D.submitBeacon();D.finish(false);
  ok("AUTO 판 제출 0건",sub===0,sub);
  ok("결과에 순위 제외 표시",/AUTO · 순위 제외/.test(document.getElementById("rankline").textContent));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
`tests/hook.js`에 `keys,autoSteer,autoPick,submitBeacon,submitScore` 추가(`keys`는 키 상태 객체 — 정의 이름을 Grep으로 확인).

- [ ] **Step 2:** 실패 확인
- [ ] **Step 3: 구현**
  - `update()` 이동: `if(touch){ix+=touch.x;iy+=touch.y;}` 다음 줄에
    ```js
    if(paidOn("auto")){G.autoUsed=true;if(!ix&&!iy){const a=autoSteer();ix=a[0];iy=a[1];}}   // 사람 입력이 이긴다
    ```
  - 함수(`near` 정의 아래):
    ```js
    /* AUTO 이동 — 피하기 · 신호권 · 상자 세 힘의 합. 영리할 필요는 없다, 순위에 안 오른다 */
    function autoSteer(){const p=G.p;let x=0,y=0;
      for(const e of G.en){if(e.dead)continue;const dx=p.x-e.x,dy=p.y-e.y,d2=dx*dx+dy*dy;
        if(d2<220*220&&d2>1){const k=9000/d2;x+=dx*k/Math.sqrt(d2);y+=dy*k/Math.sqrt(d2);}}
      for(const b of G.eb){const dx=p.x-b.x,dy=p.y-b.y,d2=dx*dx+dy*dy;
        if(d2<160*160&&d2>1){const k=14000/d2;x+=dx*k/Math.sqrt(d2);y+=dy*k/Math.sqrt(d2);}}
      if(G.boss){const dx=p.x-G.boss.x,dy=p.y-G.boss.y,d=Math.hypot(dx,dy)||1;if(d<G.boss.r+260){x+=dx/d*1.5;y+=dy/d*1.5;}}
      const z=G.zone;if(z){const dx=z.x-p.x,dy=z.y-p.y,d=Math.hypot(dx,dy)||1,w=d>z.r*.7?1.2:.25;x+=dx/d*w;y+=dy/d*w;}
      let best=null,bd=400;for(const it of G.items){if(it.type!=="chest")continue;const d=Math.hypot(it.x-p.x,it.y-p.y);if(d<bd){bd=d;best=it;}}
      if(best){const dx=best.x-p.x,dy=best.y-p.y,d=bd||1;x+=dx/d*.9;y+=dy/d*.9;}
      return [x,y];}
    /* AUTO 선택 — 진화 > 진화 조건 > 새 무기 > 강화 > 첫 장. 갈래·계약·보상은 첫 장 */
    function autoPick(){if(mode!=="level"||!paidOn("auto")&&!G.autoUsed)return;
      const cs=[...document.querySelectorAll("#picks .card")];if(!cs.length)return;
      const pick=cs.find(c=>c.classList.contains("evo"))||cs.find(c=>c.querySelector(".ev.ok"))
        ||cs.find(c=>/새 무기|전용 무기/.test(c.querySelector(".kind")?.textContent||""))
        ||cs.find(c=>/무기 강화/.test(c.querySelector(".kind")?.textContent||""))||cs[0];
      pick.click();}
    ```
  - `showVeil(s)` 끝에: `if(s==="#v-level"&&G&&paidOn("auto")){clearTimeout(G.apTO);G.apTO=setTimeout(autoPick,600);}`
  - `submitScore()` 첫 줄과 `submitBeacon()` 첫 줄에 `if(G&&G.autoUsed)return;` (submitScore는 async라 `return;`이면 된다)
  - `finish()`: `$("#rankline").textContent="순위 집계 중…";submitScore();` 를
    ```js
    $("#rankline").textContent=G.autoUsed?"AUTO · 순위 제외":"순위 집계 중…";submitScore();
    ```
    로 바꾼다. `submitScore` 안에서 `#rankline`을 다시 쓰는 경로가 있으면 AUTO일 땐 진입 전에 return하므로 그대로 남는다.
- [ ] **Step 4:** `t-auto`, `t-fast`, `t-paid`, `t-reveal`, `t-tier`, `t-smoke` PASS
- [ ] **Step 5:** 커밋 `feat: AUTO — 이동과 선택을 대신한다, 순위에는 안 올린다`

---

### Task 4: 연출 스킨

**Files:** Modify `index.html` (탄 렌더 `cx.fillStyle=b.c`, 검 렌더 `cx.fillStyle="#eef2ff"`); Create `tests/t-skin.js`; Modify `tests/hook.js`

**Interfaces:** Produces `SKINS`, `skinC(c:string):string`

- [ ] **Step 1: 테스트** `tests/t-skin.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));
  D.PAID.skin="base";ok("기본은 그대로","#4ff0d8"===D.skinC("#4ff0d8"));
  D.PAID.skin="neon";ok("네온은 바뀜",D.skinC("#4ff0d8")!=="#4ff0d8",D.skinC("#4ff0d8"));
  ok("등급 색은 표에 없음",D.TIERS.every(t=>D.skinC(t.c)===t.c));
  localStorage.removeItem("relay:master");ok("마스터 아니면 기본",D.skinC("#4ff0d8")==="#4ff0d8");
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
- [ ] **Step 2:** 실패 확인
- [ ] **Step 3: 구현** — `paidOn` 아래:
```js
/* 스킨은 내 탄·검 색만 바꾼다. 등급 색은 손대지 않는다 — 등급을 못 알아본다 */
const SKINS={base:{},
  neon:{"#4ff0d8":"#39ff88","#a86bff":"#ff3df2","#eef2ff":"#c8ff00","#ff5c8a":"#ff2a6d"},
  plat:{"#4ff0d8":"#dfe8f5","#a86bff":"#b9c4d6","#eef2ff":"#ffffff","#ff5c8a":"#e7c4cf"}};
const skinC=c=>(isMaster()&&SKINS[PAID.skin]&&SKINS[PAID.skin][c])||c;
```
`C.orange`(#ff9f43)·`C.gold`(#ffd166)는 영웅·전설 등급 색과 같으므로 스킨 표에 넣지 않는다 — 등급 색은 어떤 경로로도 바뀌면 안 된다.
렌더: 탄 `cx.fillStyle=b.c` → `cx.fillStyle=skinC(b.c)`, 꼬리 `cx.strokeStyle=b.c` → `skinC(b.c)`. 검 `cx.fillStyle="#eef2ff"` → `cx.fillStyle=skinC("#eef2ff")`.
- [ ] **Step 4:** `t-skin`, `t-reveal`, `t-flicker`, `t-smoke` PASS
- [ ] **Step 5:** 커밋 `feat: 연출 스킨 — 네온 · 백금`

---

### Task 5: 상세 통계

**Files:** Modify `index.html` (`finish()`, `#v-paid` 뒤 마크업, CSS, 배열, 함수); Create `tests/t-stats.js`; Modify `tests/hook.js`

**Interfaces:** Produces `HKEY="relay:hist"`, `pushHist():void`(finish에서 호출), `openStats():void`, `#v-stats`

- [ ] **Step 1: 테스트** `tests/t-stats.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;localStorage.setItem("relay:master",JSON.stringify(D.MASTER_H));localStorage.removeItem("relay:hist");
  for(let i=0;i<31;i++){D.start();const G=D.G;G.t=30+i;G.dmgBy={dart:100+i,blade:50,chain:10};G.autoUsed=i%2===0;D.finish(false);}
  const h=JSON.parse(localStorage.getItem("relay:hist"));
  ok("30판만 유지",h.length===30,h.length);
  ok("가장 오래된 게 빠짐",h.every(r=>r.t>=31),h.map(r=>r.t).slice(-3));
  ok("상위 무기 3개",JSON.stringify(h[0].top)===JSON.stringify(["dart","blade","chain"]),h[0].top);
  ok("AUTO 표시 저장",typeof h[0].a==="boolean");
  D.openStats();ok("목록 30줄",document.querySelectorAll("#statlist .sr").length===30);
  ok("최고 빌드 표시",/최고 빌드/.test(document.getElementById("v-stats").textContent));
  localStorage.removeItem("relay:master");D.openStats();
  ok("마스터 아니면 잠김",/유료 · 준비 중/.test(document.getElementById("v-stats").textContent));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
- [ ] **Step 2:** 실패 확인
- [ ] **Step 3: 구현** — 기록은 마스터가 아니어도 **쌓는다**(나중에 결제하면 지난 기록이 보이도록). 보기만 잠근다.
```js
const HKEY="relay:hist";
function pushHist(){const h=ls.get(HKEY,[]);
  const top=Object.keys(G.dmgBy).sort((a,b)=>G.dmgBy[b]-G.dmgBy[a]).slice(0,3);
  h.unshift({d:new Date(Date.now()+9*3600e3).toISOString().slice(0,10),s:calcScore(),t:Math.floor(G.t),lv:G.p.lv,
    ch:G.ch,form:G.form,tb:G.tierBest,top,a:!!G.autoUsed,f:!!G.fastUsed});
  ls.set(HKEY,h.slice(0,30));}
function openStats(){const h=ls.get(HKEY,[]),FN={rover:"기동계",warden:"방어계",pulse:"공진계",none:"순수"};
  if(!isMaster()){$("#statlist").innerHTML="🔒 유료 · 준비 중";$("#statbest").textContent="";showVeil("#v-stats");return;}
  $("#statlist").innerHTML=h.map(r=>`<div class="sr"><span>${r.d}</span><b>${r.s.toLocaleString()}</b>`+
    `<span>${Math.floor(r.t/60)}:${String(r.t%60).padStart(2,"0")} · LV${r.lv}</span><span>${FN[r.form]||""}</span>`+
    `<span>${r.a?"AUTO":""}${r.f?" 1.5×":""}</span></div>`).join("")||"아직 기록이 없습니다";
  const b=h.slice().sort((x,y)=>y.s-x.s)[0],cnt={};h.forEach(r=>r.top.forEach(k=>cnt[k]=(cnt[k]||0)+1));
  $("#statbest").innerHTML=b?`최고 빌드 — ${b.top.map(k=>WEAPONS[k]?WEAPONS[k].n:k).join(" · ")} (${b.s.toLocaleString()}점)<br>`+
    `자주 쓴 무기 — ${Object.keys(cnt).sort((x,y)=>cnt[y]-cnt[x]).slice(0,3).map(k=>`${WEAPONS[k]?WEAPONS[k].n:k} ${cnt[k]}판`).join(" · ")}`:"";
  showVeil("#v-stats");}
$("#b-statclose").onclick=()=>openPaid();
```
`finish()`의 `markDaily(calcScore());` 다음 줄에 `pushHist();`. 마크업(`#v-paid` 뒤):
```html
<div class="veil off" id="v-stats"><div class="box">
  <div class="tag">기록</div>
  <p id="statbest" style="margin:12px 0 0;font-size:14px;color:var(--pale)"></p>
  <div id="statlist"></div>
  <button class="btn ghost" id="b-statclose" style="margin-top:18px">닫기</button>
</div></div>
```
CSS:
```css
#statlist{max-width:560px;margin:14px auto 0;text-align:left;font-size:13px;color:var(--ash)}
#statlist .sr{display:grid;grid-template-columns:90px 90px 1fr 70px 70px;gap:8px;padding:5px 0;border-bottom:1px solid var(--line)}
#statlist .sr b{color:var(--pale)}
```
`showVeil`·`hideAll` 배열에 `"#v-stats"` 추가. 모바일 폭에서 그리드가 넘치면 `@media (max-width:620px){#statlist .sr{grid-template-columns:80px 70px 1fr}#statlist .sr span:nth-child(4),#statlist .sr span:nth-child(5){display:none}}`.
- [ ] **Step 4:** `t-stats`, `t-paid`, `t-dex`, `t-smoke` PASS
- [ ] **Step 5:** 커밋 `feat: 상세 통계 — 최근 30판과 최고 빌드`

---

### Task 6: 버전 · README · 전체 회귀

- [ ] `const VERSION="3.8.0";` → `"3.9.0"`
- [ ] README: 요약 줄에 「유료 기능(준비 중): AUTO · 1.5배속 · 스킨 · 기록」을 붙이고, `## 연속 기록` 앞에 절 추가 — AUTO는 순위 제외, 1.5배속은 순위 유지(게임 시간 기준), 스킨은 탄·검 색만, 기록은 기기에 30판. 결제는 아직 없고 마스터 코드로만 켠다는 것. **코드 원문은 쓰지 않는다.**
- [ ] 회귀: `for t in smoke tier dmgby reveal flicker dex paid fast auto skin stats; do node tests/probe.mjs tests/t-$t.js || echo "FAIL $t"; done` + `t-pc` 1920/800. FAIL 없음.
- [ ] `git diff feature/rarity-weapons --stat`와 삭제 줄 검토. (코드 원문이 저장소에 없는지는 컨트롤러가 직접 확인한다.)
- [ ] 커밋 `docs: v3.9.0 — 유료 기능 1차`
- [ ] push·PR은 사용자 확인 후.
