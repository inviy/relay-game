# 등급 무기 · 도감 · PC 큰 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 상자를 열 때 보유 무기에 에픽·영웅·전설·신화 등급이 붙고(판 안에서만), 그 기록이 도감에 남으며, PC 큰 화면에서는 무기 패널과 피해 분석이 보이게 한다.

**Architecture:** 모든 코드는 단일 파일 `index.html`의 IIFE 안에 들어간다. 등급은 `G.tier[무기키]`(0~4) 하나로 표현한다. 배율은 `weapons()` 안에서 피해를 계산하는 곳에서만 곱한다. 추첨은 새 시드 흐름 `R.tier`를 쓴다. 테스트는 헤드리스 Chrome 하네스 `tests/probe.mjs`가 `index.html` 사본에 훅을 주입해 돌린다.

**Tech Stack:** 바닐라 JS + Canvas 2D + CSS(빌드 도구 없음), Node 24(테스트 하네스), Chrome headless.

**Spec:** `docs/superpowers/specs/2026-10-10-rarity-weapons-design.md`

## Global Constraints

- 등급 표: 에픽 p=.60 ×1.15 `#b57bff` · 영웅 p=.28 ×1.30 `#ff9f43` · 전설 p=.10 ×1.50 `#ffd166` · 신화 p=.02 ×1.80 `#e8f4ff` (Task 4 실측으로 확률만 조정 가능)
- 등급은 판 안에서만 존재한다. 영구 강화 금지.
- 추첨은 `R.tier`만 쓴다. `R.zone`·`R.spawn`·`R.card`·`R.ev` 소비 순서는 바뀌면 안 된다.
- 등급은 피해 배율만 바꾼다. 개수·주기·지속·반경은 그대로.
- 중복 보상은 체력 +38(경험치 아님). 서버 SQL을 바꾸지 않는다.
- 터렛(요새)·기동계 잔상·권능(응시·파편)·궁극기·폭탄 아이템은 무기가 아니므로 배율과 기여도 집계 대상이 아니다.
- PC 조건: `innerWidth>=1200 && matchMedia("(pointer: fine)").matches`. 시야(`VS`, `W`, `H`)는 바꾸지 않는다.
- 도감 저장 키: `relay:dex`. 값 형태 `{"dart:3":{d:"YYYY-MM-DD",ch:"<기체 id>"}}`.
- 버전: `VERSION="3.8.0"`.
- 커밋마다 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 프로브는 실제 Supabase로 요청을 보내면 안 된다. 하네스가 `fetch`를 게임 스크립트보다 먼저 스텁한다.

## Review Focus

1. **이름 입력 중 `D` 키.** 메뉴의 이름 칸(`#nick`)에 「d」를 입력하면 글자가 들어가야 한다. 도감이 열리면 안 된다. → Task 6 테스트
2. **이동 키를 누른 채 상자를 먹는 경우.** 키를 계속 누르고 있으면 반복 keydown이 발생한다. 이것 때문에 전설·신화 연출이 0초 만에 닫히면 안 된다. `e.repeat`와 열린 뒤 0.4초 동안의 입력은 무시한다. → Task 5 테스트
3. **연출 도중 레벨업.** 상자 경험치로 레벨이 오르면 레벨업 화면은 연출이 닫힌 뒤에 떠야 한다(`G.pend` + `flushLevel()`). 연출을 덮어쓰거나 사라지게 하면 안 된다. → Task 5 테스트
4. **연출 도중 탭 전환.** 자동 닫힘 타이머가 숨은 탭에서 판을 재개하면 안 된다. `leave()`의 진행 중 판정에도 `reveal`을 포함한다. → Task 5 테스트
5. **이어하기로 같은 상자 다시 굴리기.** 복원 뒤 `R.tier`는 저장 시점 위치에서 이어져야 한다. 처음부터 다시 돌면 안 된다. → Task 2 테스트

---

### Task 1: 헤드리스 테스트 하네스

**Files:**
- Create: `tests/probe.mjs`
- Create: `tests/hook.js`
- Create: `tests/t-smoke.js`

**Interfaces:**
- Produces: `node tests/probe.mjs <test.js> [--w=1280] [--h=800] [--now=<epoch ms>]`. 결과를 한 줄씩 출력하고, 하나라도 실패하면 exit 1을 낸다.
- 테스트 파일 규약: `window.__dbg`(D)를 쓴다. 결과는 `[{n,ok,i}]` JSON으로 `#out`에 쓴다. 끝에 `D.mode="menu"`로 rAF 루프를 세운다.
- `tests/hook.js`는 IIFE 안의 마지막 `})();` 바로 앞에 주입된다. 클로저 변수에 접근하는 유일한 통로다.

- [ ] **Step 1: 하네스 작성**

`tests/probe.mjs`:
```js
// 헤드리스 Chrome으로 index.html 사본을 돌린다. 사용: node tests/probe.mjs tests/t-x.js [--w=1280 --h=800 --now=ms]
import {readFileSync,writeFileSync,mkdtempSync} from "node:fs";
import {execFileSync} from "node:child_process";
import {tmpdir} from "node:os";
import {join,resolve,dirname} from "node:path";
import {fileURLToPath,pathToFileURL} from "node:url";

const [,,testFile,...args]=process.argv;
const opt=Object.fromEntries(args.map(a=>a.replace(/^--/,"").split("=")));
const root=resolve(dirname(fileURLToPath(import.meta.url)),"..");
let h=readFileSync(join(root,"index.html"),"utf8");

// 실제 Supabase로 나가면 안 된다 — 게임 스크립트보다 먼저 막는다
const now=opt.now?`const _n=${+opt.now};Date.now=()=>_n+(performance.now()|0);`:"";
const STUB=`<script>${now}window.fetch=()=>Promise.resolve({ok:true,status:200,json:()=>Promise.resolve([])});`+
  `try{localStorage.clear()}catch(e){}</script>`;
if(h.split("<head>").length!==2)throw new Error("<head> must appear once");
h=h.replace("<head>","<head>"+STUB);

const i=h.lastIndexOf("})();");
if(i<0)throw new Error("IIFE end not found");
h=h.slice(0,i)+readFileSync(join(root,"tests/hook.js"),"utf8")+"\n"+h.slice(i);
h+=`<pre id="out"></pre><script>${readFileSync(resolve(testFile),"utf8")}</script>`;

const dir=mkdtempSync(join(tmpdir(),"relay-probe-"));
writeFileSync(join(root,"tests/.probe.html"),h);       // 같은 폴더 — 아이콘·매니페스트 상대경로 유지
const chrome=process.env.CHROME||"C:/Program Files/Google/Chrome/Application/chrome.exe";
const dom=execFileSync(chrome,["--headless","--disable-gpu","--allow-file-access-from-files",
  `--user-data-dir=${dir}`,`--window-size=${opt.w||1280},${opt.h||800}`,
  `--virtual-time-budget=${opt.vt||4000}`,"--dump-dom",pathToFileURL(join(root,"tests/.probe.html")).href],
  {maxBuffer:64<<20,timeout:+(opt.timeout||600000)}).toString("utf8");
const m=dom.match(/<pre id="out">([\s\S]*?)<\/pre>/);
if(!m||!m[1]){console.error("NO OUTPUT — 테스트가 예외로 멈췄을 가능성");process.exit(2);}
const txt=m[1].replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&amp;/g,"&");
let fail=0;
for(const r of JSON.parse(txt)){if(!r.ok)fail++;
  console.log(`${r.ok?"PASS":"FAIL"}  ${r.n}${r.i!==undefined?"  · "+JSON.stringify(r.i):""}`);}
process.exit(fail?1:0);
```

`tests/hook.js`:
```js
window.__dbg={get G(){return G;},get R(){return R;},get mode(){return mode;},set mode(v){mode=v;},
  start,newRun,resetSeed,update,draw,items,weapons,wstat,gainXp,saveRun,loadRun,contRun,finish,shareText,showVeil,WEAPONS};
```

`tests/t-smoke.js`:
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();
  for(let i=0;i<600;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
  ok("시간이 흐른다",D.G.t>9.9,D.G.t);
  ok("무기가 있다",Object.keys(D.G.w).length>=1,Object.keys(D.G.w));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```

`.gitignore`(없으면 만든다)에 한 줄 추가: `tests/.probe.html`

- [ ] **Step 2: 실행**

Run: `node tests/probe.mjs tests/t-smoke.js`
Expected: `PASS  시간이 흐른다` · `PASS  무기가 있다`, exit 0

- [ ] **Step 3: 커밋**

```bash
git add tests/probe.mjs tests/hook.js tests/t-smoke.js .gitignore
git commit -m "test: 헤드리스 프로브 하네스" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 등급 핵심 — 표, 추첨, 배율, 저장

**Files:**
- Modify: `index.html` — `resetSeed()`(≈797행), `RUNF`(≈756행), `newRun()`의 `G={…}`(≈1823행), `weapons()`(≈2130~2270행), `items()`의 chest 분기(≈2666행), `wstat()`(≈2905행), `contRun()`(≈3818행)
- Modify: `tests/hook.js`
- Create: `tests/t-tier.js`

**Interfaces:**
- Produces:
  - `const TIERS=[{id,n,p,m,c}×4]` — 인덱스 0=에픽 … 3=신화. 등급 값 t는 1~4(0=없음), `TIERS[t-1]`.
  - `tierMul(k:string):number` — `G.tier[k]`가 없으면 1.
  - `rollTier():{k:string,t:number,up:boolean}|null` — 보유 무기가 없으면 null. `R.tier()`를 정확히 2번 소비하고 `G.tierN+=2`.
  - `openChest(it):void` — 상자 획득 처리 전체(기존 경험치 + 등급). Task 5가 이 함수 안에 연출을 넣는다.
  - `G.tier:{[k]:1..4}`, `G.tierN:number`, `G.chestN:number`, `G.tierBest:number`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/t-tier.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=()=>D.G;

  // 1) 같은 시드면 같은 결과
  D.resetSeed();G().w={dart:1,blade:1};G().tier={};G().tierN=0;
  const a=[];for(let i=0;i<20;i++){const r=D.rollTier();a.push(r.k+r.t);}
  D.resetSeed();G().tier={};G().tierN=0;
  const b=[];for(let i=0;i<20;i++){const r=D.rollTier();b.push(r.k+r.t);}
  ok("같은 시드 같은 등급열",a.join()===b.join(),a.slice(0,6));

  // 2) 추첨이 카드 흐름을 건드리지 않는다
  D.resetSeed();for(let i=0;i<10;i++)D.rollTier();const c1=D.R.card();
  D.resetSeed();const c2=D.R.card();
  ok("R.card 불변",c1===c2);

  // 3) 등급은 오르기만 한다 + 중복은 회복
  G().tier={dart:4};G().w={dart:1};G().p.hp=10;
  const r=D.rollTier();ok("신화는 안 내려간다",G().tier.dart===4&&r.up===false);
  G().p.hp=10;G().p.mhp=120;D.openChest({x:G().p.x,y:G().p.y,type:"chest"});
  ok("중복은 체력 +38",G().p.hp===48,G().p.hp);

  // 4) 무기가 없으면 추첨 안 함
  G().w={};const n0=G().tierN;ok("무기 없음 → null",D.rollTier()===null&&G().tierN===n0);

  // 5) 배율 — 개수는 그대로, 피해만 ×1.5
  G().w={dart:3};G().lvls.dart=3;G().evo={};G().tier={};G().bul=[];G().cd.dart=0;D.weapons(0.0001);
  const base=G().bul.map(x=>x.dmg),nb=G().bul.length;
  G().tier={dart:3};G().bul=[];G().cd.dart=0;D.weapons(0.0001);
  const up=G().bul.map(x=>x.dmg);
  ok("탄 개수 동일",up.length===nb,[nb,up.length]);
  ok("피해 ×1.5",Math.abs(up[0]/base[0]-1.5)<1e-9,[base[0],up[0]]);
  ok("wstat 반영",D.wstat("dart",3).피해===Math.round((11+15)*G().st.dmg*1.5),D.wstat("dart",3));

  // 6) 이어하기 — 등급과 추첨 위치가 이어진다
  G().w={dart:1,blade:1};G().t=30;
  D.resetSeed();G().tierN=0;D.rollTier();D.rollTier();       // tierN=4
  G().tier={blade:2};                                         // 굴린 뒤에 고정 — 추첨이 blade를 올렸을 수 있다
  const expect=(()=>{D.resetSeed();for(let i=0;i<4;i++)D.R.tier();return D.R.tier();})();
  D.resetSeed();for(let i=0;i<4;i++)D.R.tier();             // 저장 직전 상태 재현
  D.saveRun();D.contRun();
  ok("복원 후 등급 유지",G().tier.blade===2,G().tier);
  ok("복원 후 추첨 위치 이어짐",D.R.tier()===expect);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
`tests/hook.js` 끝의 `WEAPONS};`를 `WEAPONS,TIERS,tierMul,rollTier,openChest};`로 바꾼다.

- [ ] **Step 2: 실패 확인**

Run: `node tests/probe.mjs tests/t-tier.js`
Expected: `NO OUTPUT` 또는 FAIL — `TIERS is not defined`(훅이 아직 없는 이름을 참조)

- [ ] **Step 3: 구현**

(a) `resetSeed()`에 흐름 추가. 기존 흐름의 오프셋(`SEED*3+k`)과 겹치지 않는 식을 쓴다:
```js
function resetSeed(){R={zone:mulberry32(SEED*3+1),spawn:mulberry32(SEED*3+2),card:mulberry32(SEED*3+3),
  ev:mulberry32(SEED*3+4),tier:mulberry32(SEED*13+5)};}
```

(b) `resetSeed` 바로 아래에 표와 함수 추가:
```js
/* ───── 등급 ─────
   상자를 열면 가진 무기 하나에 등급이 붙는다. 판이 끝나면 사라진다 — 순위표는 같은 날
   같은 조건이어야 하니까. 등급은 배율만 올린다. 탄·장판 개수를 늘리면 공속과 곱해져
   화면이 덮이고 피해가 제곱으로 뛴다(2026-09-13). 추첨은 R.tier만 쓴다 — 카드 순서가 그대로다. */
const TIERS=[
 {id:"epic",  n:"에픽",p:.60,m:1.15,c:"#b57bff"},
 {id:"hero",  n:"영웅",p:.28,m:1.30,c:"#ff9f43"},
 {id:"legend",n:"전설",p:.10,m:1.50,c:"#ffd166"},
 {id:"myth",  n:"신화",p:.02,m:1.80,c:"#e8f4ff"}];
const tierMul=k=>{const t=G.tier[k];return t?TIERS[t-1].m:1;};
function rollTier(){
  const ks=Object.keys(G.w);if(!ks.length)return null;
  const k=ks[Math.floor(R.tier()*ks.length)],u=R.tier();G.tierN+=2;
  let t=TIERS.length,acc=0;
  for(let i=0;i<TIERS.length;i++){acc+=TIERS[i].p;if(u<acc){t=i+1;break;}}
  const up=t>(G.tier[k]||0);if(up)G.tier[k]=t;
  return {k,t,up};}
```

(c) `newRun()`의 `G={…}`에 필드 추가. `ct:{},ctMode:false,` 바로 뒤에 넣는다:
```js
    tier:{},tierN:0,chestN:0,tierBest:0,
```

(d) `RUNF` 배열 끝의 `"ultReady"]`를 `"ultReady","tier","tierN","chestN","tierBest"]`로 바꾼다.

(e) `contRun()`에서 `RUNF.forEach(k=>{if(r[k]!==undefined)G[k]=r[k];});` 바로 다음 줄에 추가:
```js
  for(let i=0;i<(G.tierN||0);i++)R.tier();   // 같은 상자를 이어하기로 다시 굴리지 못하게
```

(f) `items()`의 chest 분기를 함수 호출로 바꾼다:
```js
      if(it.type==="chest")openChest(it);
```
그리고 `items()` 바로 위에 추가:
```js
/* 경험치는 예전 그대로 주고 등급을 한 번 더 굴린다. 중복이면 회복 —
   경험치로 주면 서버 레벨 상한(t/18)에 정상 기록이 걸린다. */
function openChest(it){const p=G.p;G.chestN++;
  const r=rollTier();
  if(r&&r.up)G.tierBest=Math.max(G.tierBest,r.t);
  if(r&&!r.up){p.hp=Math.min(p.mhp,p.hp+38);}
  call(r?(r.up?TIERS[r.t-1].n+" · "+WEAPONS[r.k].n:"중복 · 회복"):"보물 상자");SFX.chest();
  gainXp(p.need*1.1);}
```

(g) `weapons()` 안의 무기 피해식에서 `st.dmg`를 `st.dmg*tierMul("<키>")`로 바꾼다. 아래 목록만 바꾼다(줄 내용으로 찾는다):

| 블록 | 바꿀 식 | 키 |
|---|---|---|
| 다트/레일건 | `dmg:78*st.dmg*zoneMul()`, `dmg:(11+L*5)*st.dmg*zoneMul()` (2곳, 하나는 `*.45`가 붙음) | `"dart"` |
| 회전 검 | `const dmg=(evo?150:44+L*16)*st.dmg*zoneMul()*dt;` | `"blade"` |
| 연쇄 번개 | `const dmg=(evo?95:26+L*13)*st.dmg*zoneMul();` | `"chain"` |
| 화염 흔적 | `dps:(evo?70:16+L*7)*st.dmg*zoneMul()` | `"flame"` |
| 유도 미사일 | `dmg:(30+L*12)*st.dmg*zoneMul()` | `"missile"` |
| 충격 망치 | `const dmg=(evo?140:36+L*14)*st.dmg*zoneMul()` | `"hammer"` |
| 낙뢰 | `dmg:(evo?120:34+L*17)*st.dmg*zoneMul()` | `"bolt"` |
| 우물 | `dps:(evo?105:24+L*10)*st.dmg*zoneMul()` | `"well"` |
| 프리즘 | `dmg:(evo?76:22+L*10)*st.dmg*zoneMul()` | `"prism"` |
| 공명침 | `dmg=(evo?60:18+L*7)*st.dmg*zoneMul()` | `"needle"` |

바꾸지 않는 것: 요새 포탑 `22*st.dmg`, 기동계 잔상 `55*st.dmg`, 응시 `34*st.dmg`, 파편 `26*st.dmg`.

(h) `wstat()` 첫 줄의 `D=st.dmg`를 `D=st.dmg*tierMul(k)`로 바꾼다.

- [ ] **Step 4: 통과 확인**

Run: `node tests/probe.mjs tests/t-tier.js` → 전부 PASS
Run: `node tests/probe.mjs tests/t-smoke.js` → 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add index.html tests/hook.js tests/t-tier.js
git commit -m "feat: 상자에서 무기 등급을 굴린다 — 판 안에서만, 배율만" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 무기별 피해 기여도 집계

**Files:**
- Modify: `index.html` — `dmgE()`, `dmgB()`, `weapons()`의 투사체 생성·직접 타격, `bullets` 충돌 루프(≈2608~2613행), `pools()`(≈2630~2640행), `newRun()`
- Modify: `tests/hook.js`
- Create: `tests/t-dmgby.js`

**Interfaces:**
- Consumes: Task 2의 `G.tier`(외형 표시는 Task 5)
- Produces: `G.dmgBy:{[무기키]:number}` — 무기 피해 누적(적+보스). `dmgE(e,d,showNum,wk?)`, `dmgB(d,wk?)`. 투사체·장판·벼락 객체에 `wk` 필드.

- [ ] **Step 1: 실패하는 테스트** — `tests/t-dmgby.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();
  const G=D.G;
  G.w={dart:2,blade:2,flame:2,bolt:2};["dart","blade","flame","bolt"].forEach(k=>G.lvls[k]=2);
  for(let i=0;i<1800;i++){G.p.hp=G.p.mhp;D.update(1/60);if(D.mode!=="play")D.mode="play";}
  const s=G.dmgBy||{};
  ["dart","blade","flame","bolt"].forEach(k=>ok(k+" 집계됨",s[k]>0,s[k]));
  const total=Object.values(s).reduce((a,b)=>a+b,0);
  ok("무기 아닌 키 없음",Object.keys(s).every(k=>k in D.WEAPONS),Object.keys(s));
  ok("합계 양수",total>0,Math.round(total));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```

- [ ] **Step 2: 실패 확인**

Run: `node tests/probe.mjs tests/t-dmgby.js`
Expected: FAIL `dart 집계됨` 등

- [ ] **Step 3: 구현**

(a) `newRun()`의 `tier:{},tierN:0,chestN:0,tierBest:0,` 뒤에 `dmgBy:{},`를 추가하고, `RUNF` 끝에 `"dmgBy"`를 추가한다.

(b) `dmgE` 시그니처와 집계:
```js
function dmgE(e,d,showNum,wk){
```
`e.hp-=d; e.hit=.1;` 줄 바로 앞에 추가:
```js
  if(wk)G.dmgBy[wk]=(G.dmgBy[wk]||0)+d;
```

(c) `dmgB` 시그니처와 집계: `function dmgB(d,wk){const b=G.boss;if(!b)return;` 다음 줄에 추가:
```js
  if(wk)G.dmgBy[wk]=(G.dmgBy[wk]||0)+d;
```

(d) 꼬리표 붙이기. 줄 내용으로 찾는다:
- 다트/레일건 `G.bul.push({…})` 3곳: 객체 끝 `c:C.cyan}`, `c:C.cyan,beam:1}`, `c:C.violet}` 앞에 `wk:"dart",` 추가
- 유도 미사일 `G.bul.push`: `wk:"missile",` 추가
- 프리즘 `G.bul.push`: `wk:"prism",` 추가
- 낙뢰 `G.bolts.push({x,y,r:rad,…})`: `wk:"bolt",` 추가
- 회전 검: `dmgE(e,dmg,0)` → `dmgE(e,dmg,0,"blade")`, `dmgB(dmg)` → `dmgB(dmg,"blade")`(검 블록 안 2168행 근처)
- 연쇄 번개: `dmgE(best,dmg,1)` → `dmgE(best,dmg,1,"chain")`
- 충격 망치: `dmgE(e,dmg,1)` → `dmgE(e,dmg,1,"hammer")`, `dmgB(dmg)` → `dmgB(dmg,"hammer")`
- 공명침: `dmgB(dmg);pts.push` → `dmgB(dmg,"needle");pts.push`, `dmgE(from,dmg,1)` → `dmgE(from,dmg,1,"needle")`
- 화염·우물은 `pushPool()`이 이미 `o.k=k`를 넣는다. 그대로 쓴다.

(e) 소비하는 곳:
- 탄 충돌: `dmgE(e,b.dmg,1)` 두 곳 → `dmgE(e,b.dmg,1,b.wk)`, `dmgB(b.dmg)` → `dmgB(b.dmg,b.wk)`
- 미사일 폭발이 만드는 벼락: `G.bolts.push({x:b.x,y:b.y,r:b.blast,…,dmg:b.dmg,` 에 `wk:b.wk,` 추가
- `pools()`: `dmgE(e,q.dps*dt,0)` → `dmgE(e,q.dps*dt,0,q.k)`, `dmgB(q.dps*dt)` → `dmgB(q.dps*dt,q.k)`
- 벼락: `dmgE(e,z.dmg,1)` → `dmgE(e,z.dmg,1,z.wk)`, `dmgB(z.dmg)` → `dmgB(z.dmg,z.wk)`

`pushPool`의 키가 무기 키(`"flame"`, `"well"`)와 같은지 확인한다. 다른 호출자가 생기면 `q.k`가 무기 키가 아닐 수 있다. 테스트의 「무기 아닌 키 없음」이 그 경우를 잡는다.

- [ ] **Step 4: 통과 확인**

Run: `node tests/probe.mjs tests/t-dmgby.js` → PASS
Run: `node tests/probe.mjs tests/t-tier.js` → PASS(회귀)

- [ ] **Step 5: 커밋**

```bash
git add index.html tests/t-dmgby.js
git commit -m "feat: 무기별 피해 기여도를 센다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 실측 — 판당 상자 수, 등급 분포, 서버 레벨 상한

**Files:**
- Create: `tests/t-measure.js`
- Modify(조건부): `index.html`의 `TIERS` 확률

**Interfaces:**
- Consumes: `G.chestN`, `G.tier`, `G.tierBest`, `rollTier`
- Produces: 확정된 `TIERS[*].p`. 측정값은 커밋 메시지와 PR 본문에 기록한다.

- [ ] **Step 1: 측정 스크립트** — 무적 봇으로 11분을 돌리며 카드는 첫 장을 고른다.
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;let c3=null;
  for(let i=0;i<660*30;i++){
    G.p.hp=G.p.mhp;D.update(1/30);
    if(G.t>=180&&c3===null)c3=G.chestN;
    if(D.mode!=="play"){const b=document.querySelector(".veil:not(.off) .card");if(b)b.click();else D.mode="play";}
    if(G.over||G.dying>0)break;}                                // 종단 재머 격파 → 끝나는 연출은 loop()가 따로 돈다
  const lvcap=10+Math.floor(Math.log(Math.max(G.kills,1)+1)*4)+Math.floor(G.t/18);
  const pm=1-Math.pow(1-D.TIERS[3].p,G.chestN);
  ok("측정",true,{t:Math.round(G.t),chest:G.chestN,chest3m:c3,tier:G.tier,lv:G.p.lv,lvcap,kills:G.kills,pMythFull:+pm.toFixed(2)});
  ok("3분 안에 상자 1개 이상",c3>=1,c3);
  ok("서버 레벨 상한 통과",G.p.lv<=lvcap,[G.p.lv,lvcap]);
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```

- [ ] **Step 2: 세 날짜로 실행** (규칙이 다른 날 포함)

```bash
node tests/probe.mjs tests/t-measure.js --now=1791590400000 --timeout=900000
node tests/probe.mjs tests/t-measure.js --now=1791676800000 --timeout=900000
node tests/probe.mjs tests/t-measure.js --now=1791763200000 --timeout=900000
```
(2026-10-10/11/12 00:00 UTC)

Expected: 세 번 모두 `3분 안에 상자 1개 이상` PASS, `서버 레벨 상한 통과` PASS

- [ ] **Step 3: 확률 조정**

세 번의 `chest` 평균을 n이라 하면 신화 확률은 `p4 = 1 - 0.5^(1/n)`이다(완주 판의 절반이 신화를 한 번 보는 값). 소수 셋째 자리에서 반올림한다. `p3=.10`, `p2=.28`, `p1=1-p2-p3-p4`로 맞춘다. 값이 바뀌었으면 `TIERS`를 고치고 Global Constraints 표에도 반영한다.

`3분 안에 상자 1개 이상`이 실패하면 멈추고 사용자에게 보고한다. 이 경우 상자 주기 자체를 바꿔야 하는데, 그건 설계 범위 밖이다.

- [ ] **Step 4: 회귀 확인 후 커밋**

Run: `node tests/probe.mjs tests/t-tier.js` → PASS

```bash
git add index.html tests/t-measure.js
git commit -m "test: 판당 상자 수 실측과 등급 확률 조정" -m "실측: n=<평균>, 3분 상자=<값>, p4=<값>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 개봉 연출

**Files:**
- Modify: `index.html` — CSS(`.veil` 근처), 마크업(`#v-over` 뒤), `SFX` 객체(`chest()` 옆), `openChest()`, `showVeil()`/`hideAll()` 목록, keydown 핸들러, `leave()`, 탄·검 렌더(≈3435, 3451행)
- Modify: `tests/hook.js`
- Create: `tests/t-reveal.js`

**Interfaces:**
- Consumes: `openChest`, `rollTier`, `TIERS`, Task 6이 만들 `dexAdd(k,t):boolean`(이 Task에서는 `typeof dexAdd==="function"`일 때만 호출)
- Produces: `mode==="reveal"` 상태, `showReveal(r):void`, `closeReveal():void`, `SFX.tier(t)`, `G.revT`(에픽·영웅 연출이 떠 있는 남은 시간)

- [ ] **Step 1: 실패하는 테스트** — `tests/t-reveal.js`
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;const V=document.getElementById("v-reveal");
  const force=t=>{D.TIERS.forEach((x,i)=>x.p=i===t-1?1:0);};     // 이 페이지에서만 확률을 고정

  // 에픽 — 판이 멈추지 않는다. 상자 경험치(need×1.1)는 늘 레벨을 올리므로 mode는 "level"이 될 수 있다
  force(1);G.w={dart:1};G.tier={};D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("에픽은 reveal 아님",D.mode!=="reveal",D.mode);
  ok("에픽은 veil 안 뜸",V.classList.contains("off"));
  D.mode="play";

  // 전설 — 멈추고, 시계가 안 간다
  force(3);G.w={dart:1};G.tier={};const t0=G.t;D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("전설은 reveal",D.mode==="reveal",D.mode);
  ok("전설 veil 뜸",!V.classList.contains("off"));
  ok("시계 정지",G.t===t0);

  // 열린 직후 반복 keydown은 무시된다
  dispatchEvent(new KeyboardEvent("keydown",{key:"w",repeat:true}));
  ok("반복 키 무시",D.mode==="reveal");
  D.G.revOpen=performance.now()-1000;                            // 0.4초가 지났다고 친다
  dispatchEvent(new KeyboardEvent("keydown",{key:"x"}));
  ok("키로 닫힘",D.mode!=="reveal"&&V.classList.contains("off"),D.mode);   // 닫히면 대기 중 레벨업이 뜰 수 있다
  D.mode="play";

  // 연출 중 레벨업은 닫힌 뒤에 뜬다
  force(4);G.w={dart:1};G.tier={};G.p.xp=G.p.need-0.01;
  D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  ok("연출 중엔 레벨업 대기",D.mode==="reveal"&&G.pend>=1,{mode:D.mode,pend:G.pend});
  D.closeReveal();
  ok("닫으면 레벨업",D.mode==="level",D.mode);
  D.mode="play";D.showVeil("#v-menu");

  // 숨은 탭에서 자동 닫힘 → 일시정지
  force(3);G.w={dart:1};G.tier={};D.mode="play";D.openChest({x:G.p.x,y:G.p.y,type:"chest"});
  Object.defineProperty(document,"hidden",{configurable:true,get:()=>true});
  D.closeReveal();
  ok("숨은 탭이면 pause",D.mode==="pause",D.mode);
  delete document.hidden;
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
`tests/hook.js`의 끝 `openChest};`를 `openChest,showReveal,closeReveal};`로 바꾼다.

- [ ] **Step 2: 실패 확인**

Run: `node tests/probe.mjs tests/t-reveal.js` → NO OUTPUT 또는 FAIL

- [ ] **Step 3: 마크업과 CSS**

`#v-over` 블록의 닫는 `</div></div>` 바로 뒤에 추가:
```html
<div class="veil off" id="v-reveal"><div class="box">
  <div id="rv-beam"></div>
  <div id="rv-card"><div class="tag" id="rv-tier"></div><h2 id="rv-name"></h2><p id="rv-sub"></p><p id="rv-new">NEW · 도감 등록</p></div>
  <p class="rv-skip">탭하거나 아무 키나 누르면 넘깁니다</p>
</div></div>
```
`.veil.off{display:none}` 줄 바로 뒤에 추가:
```css
/* 개봉 — 빛기둥이 보라→주황→금으로 차오르다 멈춘다. 신화만 한 칸 더 간다.
   금에서 멈출지 모르는 1초가 이 장치의 전부다 */
#v-reveal{align-items:center;background:rgba(4,6,14,.82)}
#v-reveal .box{position:relative;min-height:320px;display:flex;flex-direction:column;align-items:center;justify-content:center}
#rv-beam{width:90px;height:260px;border-radius:45px;filter:blur(18px);animation:rvbeam 1.2s steps(1,end) forwards}
#v-reveal.myth #rv-beam{animation:rvbeamM 1.6s steps(1,end) forwards}
@keyframes rvbeam{0%{background:#b57bff}33%{background:#ff9f43}66%,100%{background:#ffd166}}
@keyframes rvbeamM{0%{background:#b57bff}25%{background:#ff9f43}50%{background:#ffd166}75%,100%{background:#e8f4ff}}
#rv-card{position:absolute;opacity:0;transform:rotateY(90deg);animation:rvcard .35s ease-out 1.2s forwards}
#v-reveal.myth #rv-card{animation-delay:1.6s}
@keyframes rvcard{to{opacity:1;transform:none}}
#rv-tier{font-size:15px;letter-spacing:.2em}
#rv-new{display:none;color:var(--gold);font-weight:700;letter-spacing:.12em;margin-top:6px}
#v-reveal.new #rv-new{display:block}
.rv-skip{position:absolute;bottom:4px;left:0;right:0;font-size:13px;opacity:.55}
```

`showVeil()`와 `hideAll()`의 배열 `["#v-menu","#v-level","#v-pause","#v-over"]`에 `"#v-reveal"`을 추가한다(두 곳). `showVeil`의 HUD 표시 조건 `(s==="#v-level"||s==="#v-pause")`에 `||s==="#v-reveal"`을 추가한다.

- [ ] **Step 4: 소리** — `SFX` 객체의 `chest(){…},` 줄 바로 뒤에 추가:
```js
  /* 등급마다 끝음이 한 음씩 오른다. 신화는 화음, 그리고 한 박자 쉬고 친다 */
  tier(t){[660,880,1100,1320].forEach((f,i)=>tone(f,.18,"triangle",.22,0,i*.06));
    const top=1320*Math.pow(2,2*t/12),d=.3+(t>=4?.25:0);
    tone(top,.5,"triangle",.26,0,d);
    if(t>=4){tone(top*1.25,.7,"sine",.16,0,d);tone(top*1.5,.7,"sine",.14,0,d);}},
```

- [ ] **Step 5: 연출 로직** — `openChest`를 아래로 교체하고 `showReveal`·`closeReveal`을 붙인다:
```js
/* 경험치는 예전 그대로 주고 등급을 한 번 더 굴린다. 중복이면 회복 —
   경험치로 주면 서버 레벨 상한(t/18)에 정상 기록이 걸린다.
   전설·신화는 판을 멈추고 보여준다. 경험치는 연출을 연 뒤에 넣는다 — 그래야
   레벨업이 G.pend에 쌓였다가 연출이 닫힌 뒤 flushLevel()로 뜬다. */
function openChest(it){const p=G.p;G.chestN++;
  const r=rollTier(),T=r?TIERS[r.t-1]:null;
  if(!r){call("보물 상자");SFX.chest();gainXp(p.need*1.1);return;}
  if(!r.up){p.hp=Math.min(p.mhp,p.hp+38);call("중복 · 회복");SFX.chest();gainXp(p.need*1.1);return;}
  G.tierBest=Math.max(G.tierBest,r.t);
  const isNew=typeof dexAdd==="function"&&dexAdd(r.k,r.t);
  SFX.tier(r.t);
  const big=document.body.classList.contains("bigpc")?1.6:1;
  sprFx("burst",it.x,it.y,(r.t>=3?320:220)*big,T.c,.6,{a:.9,g0:.3,must:1});
  if(r.t>=3)showReveal(r,isNew);
  else if(G.revT>0&&r.t<=G.revTier)call(T.n+" · "+WEAPONS[r.k].n);  // 0.5초 안에 더 낮은 게 오면 작은 줄로
  else{G.revT=.5;G.revTier=r.t;callBig(T.n+" · "+WEAPONS[r.k].n,"피해 ×"+T.m+(isNew?" · NEW 도감 등록":""));}
  gainXp(p.need*1.1);}
function showReveal(r,isNew){const T=TIERS[r.t-1],V=$("#v-reveal");
  V.classList.toggle("myth",r.t>=4);V.classList.toggle("new",!!isNew);
  $("#rv-tier").textContent=T.n.split("").join(" ");$("#rv-tier").style.color=T.c;
  $("#rv-name").textContent=WEAPONS[r.k].n;$("#rv-sub").textContent="피해 ×"+T.m;
  mode="reveal";G.revOpen=performance.now();showVeil("#v-reveal");
  clearTimeout(G.revTO);G.revTO=setTimeout(closeReveal,r.t>=4?2600:2200);}
function closeReveal(){if(mode!=="reveal")return;clearTimeout(G.revTO);
  hideAll();mode="play";last=performance.now();
  if(document.hidden){pause();return;}   // 숨은 탭에서 타이머가 판을 재개하면 안 된다
  flushLevel();}
```
`update(dt)` 첫 줄 `const p=G.p; G.t+=dt;…` 바로 다음 줄에 추가:
```js
  if(G.revT>0)G.revT-=dt;
```
`#v-reveal`을 탭하면 닫히게 `$("#b-again").onclick=start;` 근처에 추가:
```js
$("#v-reveal").onclick=()=>{if(performance.now()-G.revOpen>400)closeReveal();};
```

- [ ] **Step 6: keydown과 leave**

keydown 핸들러 맨 앞(`keys[e.key.toLowerCase()]=1;` 바로 다음)에 추가:
```js
  if(mode==="reveal"){if(!e.repeat&&performance.now()-G.revOpen>400)closeReveal();e.preventDefault();return;}
```
`leave()`의 `(mode==="play"||mode==="pause"||mode==="level")`에 `||mode==="reveal"`을 추가한다.

- [ ] **Step 7: 판 내내 등급 색** — 신화의 「고유 외형」은 더 큰 `shadowBlur`로 낸다. 스펙은 Kenney 텍스처를 언급했지만, 텍스처 글로우는 `shadowBlur`보다 1.8배 느리다는 실측이 있어 쓰지 않는다. 탄 렌더 `for(const b of G.bul){cx.shadowColor=b.c;cx.fillStyle=b.c;`를 다음으로 바꾼다:
```js
  for(const b of G.bul){const tt=b.wk&&G.tier[b.wk];
    cx.shadowColor=tt?TIERS[tt-1].c:b.c;cx.fillStyle=b.c;cx.shadowBlur=tt>=4?26:16;
```
검 렌더 `cx.shadowColor="#dfe6ff";cx.shadowBlur=18;`를 다음으로 바꾼다:
```js
    const bt=G.tier.blade;cx.shadowColor=bt?TIERS[bt-1].c:"#dfe6ff";cx.shadowBlur=bt>=4?28:18;
```

- [ ] **Step 8: 통과 확인 + 깜빡임 측정**

Run: `node tests/probe.mjs tests/t-reveal.js` → PASS
Run: `node tests/probe.mjs tests/t-tier.js` → PASS. 이 테스트의 「중복은 체력 +38」은 여전히 `openChest`를 쓰므로 회귀를 잡는다.

깜빡임: `tests/t-flicker.js`를 만든다. 에픽 상자 5개를 1초 안에 연다. 그 뒤 매 프레임 `draw()`를 부르고 게임 캔버스를 `getImageData`로 64×64 격자 표본을 떠서 평균 밝기를 구한다. 결과는 프레임 간 변동폭 `max−avg`이다.
```js
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
```
`tests/hook.js`에 `draw`가 이미 있다. 캔버스 id가 `cv`인지 먼저 확인한다(`const cv=$("#cv")`).
Run: `node tests/probe.mjs tests/t-flicker.js` → PASS. 실패하면 `sprFx` 크기와 `a`를 낮추고 다시 잰다.

- [ ] **Step 9: 커밋**

```bash
git add index.html tests/hook.js tests/t-reveal.js tests/t-flicker.js
git commit -m "feat: 상자 개봉 연출 — 에픽·영웅은 흐름 안에서, 전설·신화는 멈춰서" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 도감

**Files:**
- Modify: `index.html` — 메뉴 마크업(`.mstats` 다음), `#v-over` 마크업(`#ozone` 앞), 새 `#v-dex` veil, CSS, `ls` 근처에 도감 함수, `finish()`, `shareText()`, `menu()`, keydown, `track("end",…)`
- Modify: `tests/hook.js`
- Create: `tests/t-dex.js`

**Interfaces:**
- Consumes: `TIERS`, `WEAPONS`, `G.tierBest`, `G.tier`, `openChest`의 `dexAdd` 호출(Task 5)
- Produces: `DKEY="relay:dex"`, `dexAdd(k:string,t:number):boolean`(새 칸이면 true), `dexCount():number`, `openDex():void`, `G.dexNew:number`

- [ ] **Step 1: 실패하는 테스트** — `tests/t-dex.js`
```js
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
  D.mode="menu";D.showVeil("#v-menu");
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
```
`tests/hook.js` 끝 `closeReveal};`를 `closeReveal,dexAdd,dexCount,openDex};`로 바꾼다.

- [ ] **Step 2: 실패 확인** — `node tests/probe.mjs tests/t-dex.js` → NO OUTPUT 또는 FAIL

- [ ] **Step 3: 저장 함수** — `const ls={…};` 정의 바로 뒤에 추가:
```js
/* 도감 — 뽑아 본 「무기 × 등급」을 남긴다. 힘은 주지 않는다(순위표가 오염된다).
   기기 안에만 쌓인다. 폰과 PC가 따로인 건 알고 간다 — 아쉬워하는 사람이 생기면 서버로 */
const DKEY="relay:dex";
function dexAdd(k,t){const d=ls.get(DKEY,{}),id=k+":"+t;
  if(d[id])return false;
  d[id]={d:new Date(Date.now()+9*3600e3).toISOString().slice(0,10),ch:G.ch};ls.set(DKEY,d);
  G.dexNew=(G.dexNew||0)+1;return true;}
const dexCount=()=>Object.keys(ls.get(DKEY,{})).length;
```
`newRun()`의 `dmgBy:{},` 뒤에 `dexNew:0,`을 추가하고, `RUNF` 끝에 `"dexNew"`를 추가한다.

- [ ] **Step 4: 마크업·CSS**

메뉴: `<p class="mstats">…</p>` 줄 바로 뒤에 추가:
```html
  <p id="dexlink" style="margin:6px 0 0;font-size:13.5px;color:var(--ash);cursor:pointer">도감 <b id="dexn" class="mono">0</b>/40</p>
```
결과: `<div id="ozone"></div>` 바로 앞에 추가:
```html
  <p id="dexline" style="margin:2px 0 0;font-size:14px;color:var(--ash)"></p>
```
`#v-reveal` 블록 뒤에 추가:
```html
<div class="veil off" id="v-dex"><div class="box">
  <div class="tag">도감</div>
  <h2 style="margin-top:10px">뽑아 본 무기 <span id="dexn2" class="mono"></span>/40</h2>
  <div id="dexgrid"></div>
  <button class="btn ghost" id="b-dexclose" style="margin-top:18px">닫기</button>
</div></div>
```
CSS(`#rv-new` 규칙 뒤):
```css
#dexgrid{display:grid;grid-template-columns:auto repeat(4,1fr);gap:6px;margin-top:16px;align-items:center;font-size:13px}
#dexgrid .wn{text-align:left;color:var(--pale);padding-right:8px}
#dexgrid .dc{height:30px;border:1px solid var(--line);border-radius:3px;display:flex;align-items:center;justify-content:center;color:var(--ash)}
#dexgrid .dc.got{border-color:var(--c);color:var(--c);box-shadow:inset 0 0 12px -4px var(--c)}
```
`showVeil()`·`hideAll()` 배열에 `"#v-dex"`를 추가한다(두 곳).

- [ ] **Step 5: 화면 로직** — `function menu(){` 위에 추가:
```js
function openDex(){const d=ls.get(DKEY,{});let h="";
  for(const k in WEAPONS){h+=`<span class="wn">${WEAPONS[k].n}</span>`;
    TIERS.forEach((T,i)=>{const g=d[k+":"+(i+1)];
      h+=`<span class="dc${g?" got":""}" style="--c:${T.c}" title="${g?g.d:""}">${g?T.n:"?"}</span>`;});}
  $("#dexgrid").innerHTML=h;$("#dexn2").textContent=dexCount();showVeil("#v-dex");}
$("#dexlink").onclick=openDex;
$("#b-dexclose").onclick=()=>showVeil("#v-menu");
```
`menu()` 안의 `$("#runs").textContent=SAVE.runs;` 다음 줄에 추가:
```js
  $("#dexn").textContent=dexCount();
```
keydown 핸들러에 `if(mode==="reveal")…` 줄 다음으로 추가:
```js
  if(mode==="menu"&&e.key.toLowerCase()==="d"&&!/INPUT|SELECT|TEXTAREA/.test((e.target&&e.target.tagName)||"")){
    $("#v-dex").classList.contains("off")?openDex():showVeil("#v-menu");return;}
```

- [ ] **Step 6: 결과·공유·분석**

`finish()`의 `$("#build").innerHTML=bh;` 바로 앞에 추가:
```js
  $("#dexline").textContent=G.dexNew?`이번 판 도감 +${G.dexNew} · ${dexCount()}/40`:"";
```
같은 `finish()`의 무기 칩 생성 `bh+=\`<span class="wchip" style="--c:${WEAPONS[k].c}">` 에서 칩 색을 등급 색으로 바꾼다:
```js
    const tt=G.tier[k];
    bh+=`<span class="wchip" style="--c:${tt?TIERS[tt-1].c:WEAPONS[k].c}"><b>${tt?TIERS[tt-1].n+" ":""}${ev?ev.n:WEAPONS[k].n}</b> ${ev?"MAX":"Lv"+G.lvls[k]}</span>`;}
```
(`let bh="";for(const k in G.w){const ev=…;` 다음의 기존 `bh+=…;}` 한 줄을 위 두 줄로 교체)

`track("end",{…,score:calcScore()}` 객체에 `tier:G.tierBest,chests:G.chestN`을 추가한다.

`shareText()`의 `if(sd)L.push(…);` 다음 줄에 추가:
```js
  const my=Object.keys(G.tier).filter(k=>G.tier[k]===4).map(k=>WEAPONS[k].n);
  if(my.length)L.push("신화 · "+my.join(" · "));
```

- [ ] **Step 7: 통과 확인** — `node tests/probe.mjs tests/t-dex.js` → PASS. `t-reveal.js`, `t-tier.js`도 PASS여야 한다.

- [ ] **Step 8: 커밋**

```bash
git add index.html tests/hook.js tests/t-dex.js
git commit -m "feat: 도감 — 뽑아 본 무기×등급 40칸, 결과·공유에 한 줄" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: PC 큰 화면 — 무기 패널, 결과 피해 분석

**Files:**
- Modify: `index.html` — `resize()`, HUD 마크업(`#callbig` 다음), CSS, `update()`, `finish()`
- Modify: `tests/hook.js`
- Create: `tests/t-pc.js`

**Interfaces:**
- Consumes: `G.dmgBy`, `G.tier`, `TIERS`, `WEAPONS`, `EVOS`
- Produces: `bigPC():boolean`, `body.bigpc` 클래스, `drawPanel():void`, `#wpanel`, `#dmgbars`

- [ ] **Step 1: 실패하는 테스트** — `tests/t-pc.js`(창 크기는 하네스 인자로 바꾼다)
```js
(()=>{const out=[],ok=(n,c,i)=>out.push({n,ok:!!c,i});
try{
  const D=window.__dbg;D.start();const G=D.G;const want=innerWidth>=1200;
  ok("bigPC 판정",D.bigPC()===(want&&matchMedia("(pointer: fine)").matches),{w:innerWidth});
  ok("body.bigpc",document.body.classList.contains("bigpc")===D.bigPC());
  G.w={dart:2,blade:1};G.lvls.dart=2;G.lvls.blade=1;G.tier={dart:3};G.dmgBy={dart:300,blade:100};
  for(let i=0;i<30;i++){D.update(1/60);if(D.mode!=="play")D.mode="play";}
  const P=document.getElementById("wpanel");
  if(D.bigPC()){
    ok("패널 보임",getComputedStyle(P).display!=="none");
    ok("패널에 무기 2줄",P.querySelectorAll(".wp").length===2,P.innerHTML.length);
  }else ok("패널 숨김",getComputedStyle(P).display==="none");
  D.finish(false);const B=document.getElementById("dmgbars");
  ok("결과 피해 분석",D.bigPC()?B.children.length===2:B.innerHTML==="",B.innerHTML.slice(0,80));
}catch(e){ok("예외 없음",false,String(e.stack||e));}
window.__dbg.mode="menu";
document.getElementById("out").textContent=JSON.stringify(out);})();
```
`tests/hook.js` 끝 `openDex};`를 `openDex,bigPC};`로 바꾼다.

- [ ] **Step 2: 실패 확인**

```bash
node tests/probe.mjs tests/t-pc.js --w=1920 --h=1080
node tests/probe.mjs tests/t-pc.js --w=800 --h=900
```
Expected: NO OUTPUT 또는 FAIL

- [ ] **Step 3: 판정** — `resize()`의 마지막 문장 `cx.setTransform(k,0,0,k,0,0);}` 를 다음으로 바꾼다:
```js
  cx.setTransform(k,0,0,k,0,0);
  document.body.classList.toggle("bigpc",bigPC());}
```
그리고 `resize` 정의 바로 위에 추가(시야는 건드리지 않는다):
```js
/* PC 큰 화면 — 연출과 정보만 더 준다. 시야는 이미 폰보다 1.7배 넓으니 더 벌리지 않는다 */
const bigPC=()=>innerWidth>=1200&&matchMedia("(pointer: fine)").matches;
```

- [ ] **Step 4: 무기 패널** — `<div id="callbig">…</div>` 줄 바로 뒤에 추가:
```html
  <div id="wpanel"></div>
```
CSS(`#dexgrid` 규칙 뒤):
```css
#wpanel{display:none;position:absolute;left:16px;top:50%;transform:translateY(-50%);width:200px;pointer-events:none}
body.bigpc #wpanel{display:block}
#wpanel .wp{border-left:3px solid var(--c);padding:5px 8px;margin:6px 0;background:rgba(13,18,36,.55);font-size:12.5px;color:var(--pale)}
#wpanel .wp i{display:block;height:3px;margin-top:4px;background:var(--c);width:calc(var(--f)*100%);font-style:normal}
#wpanel .wp em{font-style:normal;color:var(--c);margin-right:4px}
```
`update(dt)`의 `if(G.revT>0)G.revT-=dt;` 다음 줄에 추가:
```js
  if(document.body.classList.contains("bigpc")){G.panT=(G.panT||0)-dt;if(G.panT<=0){G.panT=.25;drawPanel();}}
```
`openDex` 정의 위에 추가:
```js
function drawPanel(){let tot=0;for(const k in G.w)tot+=G.dmgBy[k]||0;let h="";
  for(const k in G.w){const t=G.tier[k],T=t?TIERS[t-1]:null,ev=EVOS.find(e=>e.w===k&&G.evo[e.id]);
    h+=`<div class="wp" style="--c:${T?T.c:WEAPONS[k].c};--f:${tot?((G.dmgBy[k]||0)/tot).toFixed(3):0}">`+
       `${T?`<em>${T.n}</em>`:""}${ev?ev.n:WEAPONS[k].n} · ${ev?"MAX":"Lv"+G.lvls[k]}<i></i></div>`;}
  $("#wpanel").innerHTML=h;}
```

- [ ] **Step 5: 결과 피해 분석** — 마크업 `<div id="build" …></div>` 바로 앞에 추가:
```html
  <div id="dmgbars"></div>
```
CSS:
```css
#dmgbars{max-width:420px;margin:0 auto 14px;text-align:left}
#dmgbars div{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--pale);margin:4px 0}
#dmgbars span{width:120px;flex:none}
#dmgbars i{height:8px;background:var(--c);width:calc(var(--f)*100%);display:block}
#dmgbars b{margin-left:auto;font-weight:600;color:var(--ash)}
```
`finish()`의 `$("#build").innerHTML=bh;` 바로 뒤에 추가:
```js
  /* PC에서만 — 다음 판에 무엇을 키울지 고민하게 만드는 표 */
  let dh="";if(bigPC()){let tot=0;for(const k in G.dmgBy)tot+=G.dmgBy[k];
    Object.keys(G.dmgBy).sort((a,b)=>G.dmgBy[b]-G.dmgBy[a]).forEach(k=>{const t=G.tier[k],f=tot?G.dmgBy[k]/tot:0;
      dh+=`<div style="--c:${t?TIERS[t-1].c:WEAPONS[k].c};--f:${f.toFixed(3)}"><span>${t?TIERS[t-1].n+" ":""}${WEAPONS[k].n}</span>`+
          `<i></i><b>${Math.round(f*100)}%</b></div>`;});}
  $("#dmgbars").innerHTML=dh;
```

- [ ] **Step 6: 개봉 카드 확대** — CSS 추가:
```css
body.bigpc #v-reveal .box{transform:scale(1.35)}
```
(입자 확대는 Task 5의 `openChest`가 이미 `bigpc`를 본다)

- [ ] **Step 7: 통과 확인**

```bash
node tests/probe.mjs tests/t-pc.js --w=1920 --h=1080
node tests/probe.mjs tests/t-pc.js --w=800 --h=900
```
Expected: 둘 다 전부 PASS. 헤드리스 Chrome의 `pointer: fine`이 false로 나오면 1920 쪽도 「패널 숨김」 분기로 간다. 이 경우 출력의 `bigPC 판정` 정보로 확인하고 결과를 그대로 보고한다. 검증하지 못한 부분은 실기기 확인 항목으로 넘긴다.

- [ ] **Step 8: 커밋**

```bash
git add index.html tests/hook.js tests/t-pc.js
git commit -m "feat: PC 큰 화면 — 무기 패널과 결과 피해 분석" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 버전, README, 전체 회귀, PR 준비

**Files:**
- Modify: `index.html` — `const VERSION="3.6.9";`
- Modify: `README.md`

- [ ] **Step 1: 버전** — `const VERSION="3.6.9";` → `const VERSION="3.8.0";`(PR #9가 3.7.0)

- [ ] **Step 2: README** — 첫 요약 줄의 `현재 v3.6.9 — …`를 `현재 v3.8.0 — …, 상자 등급 무기(판 안에서만) · 도감`으로 바꾼다. `## 연속 기록` 절 바로 앞에 절을 하나 추가한다:
```markdown
## 상자 — 등급 무기

보물 상자를 열면 가진 무기 하나에 등급이 붙습니다. **판이 끝나면 사라집니다** — 순위표는 같은 날 같은 조건이어야 하니까요.

| 등급 | 확률 | 피해 |
|---|---|---|
| 에픽 | 60% | ×1.15 |
| 영웅 | 28% | ×1.30 |
| 전설 | 10% | ×1.50 |
| 신화 | 2% | ×1.80 |

등급은 피해 배율만 올립니다. 탄·장판 개수를 늘리면 공속과 곱해져 화면을 덮습니다. 이미 더 높은 등급이면 「중복」이고 체력을 채워 줍니다. 추첨은 오늘 시드의 별도 흐름이라, 같은 날 같은 순서로 상자를 열면 같은 결과가 나옵니다.

**도감** — 뽑아 본 「무기 × 등급」 40칸이 기기에 남습니다. 힘은 주지 않습니다.

**PC 큰 화면(1200px 이상, 마우스)** — 왼쪽에 무기 패널(등급 · 피해 기여도)이 뜨고, 결과 화면에 무기별 피해 비율이 나옵니다. 시야는 넓히지 않습니다.
```
(Task 4에서 확률이 바뀌었으면 표도 그 값으로 쓴다)

- [ ] **Step 3: 전체 회귀**

```bash
for t in smoke tier dmgby reveal flicker dex; do node tests/probe.mjs tests/t-$t.js || echo "FAIL $t"; done
node tests/probe.mjs tests/t-pc.js --w=1920 --h=1080
node tests/probe.mjs tests/t-pc.js --w=800 --h=900
```
(게임 스크립트에 문법 오류가 있으면 하네스가 `NO OUTPUT`으로 실패한다 — 별도 문법 검사는 두지 않는다)
Expected: FAIL 줄 없음

- [ ] **Step 4: diff 검토** — `git diff main --stat`, `git diff main -- index.html | grep '^-' | grep -v '^---'`. 삭제된 줄이 모두 이 계획에서 바꾼 줄인지 확인한다.

- [ ] **Step 5: 커밋**

```bash
git add index.html README.md
git commit -m "docs: v3.8.0 — 등급 무기 · 도감 · PC 큰 화면" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: push·PR은 사용자 확인 후** — `git push -u origin feature/rarity-weapons`, `gh pr create`. 본문에 Task 4 실측값을 적고, 실기기에서 봐 달라는 세 가지를 적는다. ① 신화 연출이 설레는지 ② 에픽·영웅 연출이 전투를 끊지 않는지 ③ PC 패널이 거슬리지 않는지.
