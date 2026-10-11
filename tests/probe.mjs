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
