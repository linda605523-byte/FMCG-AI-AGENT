/**
 * eBest FMCG Demo · LLM 代理（Cloudflare Worker）
 * 方案A：在现有 Worker 基础上升级——绑定自定义域名后替换此代码即可
 *
 * 前端约定：
 *   POST /  {system, messages:[{role,content}]}  →  {text}
 *   GET  /ping                                   →  {ok:true}  （健康检查，不消耗 DeepSeek 额度）
 *
 * 配置（Cloudflare 后台 → Worker → Settings → Variables and Secrets）：
 *   DEEPSEEK_KEY  = sk-xxxxxxxx   （DeepSeek API Key，Secret 类型）
 *   MODEL         = deepseek-chat （可选，默认 deepseek-chat）
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    const url = new URL(request.url);

    // 健康检查：给前端状态灯用，不打 DeepSeek
    if (request.method === 'GET' && url.pathname === '/ping') {
      return json({ ok: true, ts: Date.now() });
    }
    if (request.method !== 'POST') {
      return json({ error: 'method not allowed' }, 405);
    }

    try {
      const body = await request.json();
      const model = env.MODEL || 'deepseek-chat';
      const upstream = await fetch('https://api.deepseek.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + env.DEEPSEEK_KEY,
        },
        body: JSON.stringify({
          model,
          messages: [
            ...(body.system ? [{ role: 'system', content: body.system }] : []),
            ...(body.messages || []),
          ],
          temperature: 0.4,
        }),
      });
      const data = await upstream.json();
      const text = data.choices && data.choices[0] && data.choices[0].message
        ? data.choices[0].message.content : '';
      return json({ text });
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}
