#!/bin/bash
# Pre-deploy regression check for FMCG demo (index.html)
# Usage: bash regression.sh [path-to-html]   (default: index.html)
set -e
F="${1:-index.html}"
PASS=0; FAIL=0; FAILED=""
ok(){ PASS=$((PASS+1)); }
no(){ FAIL=$((FAIL+1)); FAILED="$FAILED $1"; }

# 1) JS syntax of the MAIN app script block
python3 - "$F" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
blocks=re.findall(r'<script[^>]*>(.*?)</script>', s, re.S)
app=[b for b in blocks if 'function build3DRoomSphere' in b]
assert len(app)==1, 'main app block not uniquely found'
open('/tmp/_rg_check.js','w').write(app[0])
PY
if node --check /tmp/_rg_check.js 2>/dev/null; then echo "PASS syntax"; else echo "FAIL syntax"; no syntax; fi

# 2) In-page functional checks (headless, mock data, no real LLM)
cp "$F" /tmp/_rg_test.html
cat > /tmp/_rg_inj.html <<'EOF'
<script>
function rgRun(){
 var R=[];
 function chk(n,c){ R.push((c?'ok':'NO')+':'+n); }
 try{ currentLang='zh';
  // agent panel opens once (no double-bind)
  bindQuickActions(); bindQuickActions();
  var qa=document.getElementById('quickActions'); qa.innerHTML='<button class="quick-btn" data-action="A14" data-type="agent">A14</button>';
  var b0=document.querySelectorAll('#messagesContainer .msg.ai').length;
  qa.querySelector('.quick-btn').click();
  setTimeout(function(){
   var opened=document.querySelectorAll('#messagesContainer .msg.ai').length-b0;
   chk('agentPanelOnce', opened===1);
   // orchestration render (good mock)
   var good=parseOrchestration('@@ORCH@@\nINTENT: 测试意图\n@@AGENT@@ A11 | 趋势\n**趋势**\n- 同比-3%\n@@AGENT@@ S6 | 周报\n周报内容\n@@SYNTH@@\n结论要点\n@@END@@');
   chk('orchParse2agents', good.agents.length===2);
   var oc=document.createElement('div'); oc.innerHTML=renderOrchestration(good);
   chk('orchNoRawLeak', !/@@AGENT@@|@@SYNTH@@/.test(oc.innerText));
   chk('orchHasSynthesis', /结论要点/.test(oc.innerText));
   // truncated -> graceful
   var tr=parseOrchestration('@@ORCH@@\nINTENT: x\n@@AGENT@@ A11 | t\n部分内容被截断');
   chk('truncSafe', tr.agents.length===1);
   // zero-agent -> hide empty plan
   var z=document.createElement('div'); z.innerHTML=renderOrchestration(parseOrchestration('@@ORCH@@\nINTENT: y\n@@SYNTH@@\n仅结论'));
   chk('zeroAgentHidesPlan', !/0 个 Agent/.test(z.innerText));
   // messy ids
   var mp=parseOrchestration('**@@ORCH@@**\nINTENT: z\n**@@AGENT@@** **a11** | t\n内容\n@@SYNTH@@\nok');
   chk('messyIdParsed', mp.agents.length===1 && mp.agents[0].id==='A11');
   // poster
   showPosterModal({title:'测试',mechanic:'买二送一',theme:'mint'});
   chk('posterModal', !!document.getElementById('posterModal') && !!document.querySelector('#posterModal img'));
   var pm=document.getElementById('posterModal'); if(pm) pm.remove();
   // 3D builds
   build3DRoom(['data:image/gif;base64,R0lGODlhAQABAAAAACwAAAAAAQABAAA=']);
   setTimeout(function(){
     chk('threeDBuilds', !!document.querySelector('.s3v-stage')||!!document.querySelector('.s3d-stage'));
     var s=document.querySelector('.s3v-stage,.s3d-stage'); if(s) s.remove();
     // EN: render all agent/skill bodies, scan CJK
     try{ applyLanguage('en'); }catch(e){}
     var box=document.createElement('div');
     try{ agents.concat(skills).forEach(function(it){ try{ box.innerHTML+=renderResultBody(it,{}); }catch(e){} }); }catch(e){}
     document.body.appendChild(box);
     try{ localizeEl(box); }catch(e){}
     var cjk=(box.innerText.match(/[\u4e00-\u9fff]/g)||[]).length;
     chk('enZeroCJK', cjk===0);
     document.title='RG '+R.join(' ');
   },700);
  },400);
 }catch(e){ document.title='RG ERR '+e.message; }
}
window.addEventListener('load',function(){ setTimeout(rgRun,400); });
</script>
EOF
python3 -c "
s=open('/tmp/_rg_test.html').read(); inj=open('/tmp/_rg_inj.html').read()
open('/tmp/_rg_test.html','w').write(s.replace('</body>',inj+'\n</body>',1))"
OUT=$(timeout 60 /opt/google/chrome/chrome --headless --no-sandbox --disable-gpu --use-gl=swiftshader --enable-unsafe-swiftshader --virtual-time-budget=8000 --dump-dom "file:///tmp/_rg_test.html" 2>/dev/null | grep -oP '(?<=<title>)RG[^<]*' | head -1)
echo "$OUT" | tr ' ' '\n' | while read tok; do
  case "$tok" in
    ok:*) echo "PASS ${tok#ok:}";;
    NO:*) echo "FAIL ${tok#NO:}";;
  esac
done
# tally for exit status
echo "$OUT" | grep -q 'NO:' && echo "=== REGRESSION FAILED ===" || echo "=== ALL GREEN ==="
