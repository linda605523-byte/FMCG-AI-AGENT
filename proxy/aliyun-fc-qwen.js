/**
 * eBest FMCG Demo · LLM 代理（阿里云函数计算 FC · Node.js 18）
 * 国内可达代理，对接阿里云百炼（千问）
 *
 * 前端约定（与现有 Cloudflare Worker 完全一致，前端零改动）：
 *   POST /      {system, messages:[{role,content}]}  →  {text}
 *   GET  /ping                                     →  {ok:true}
 *
 * 环境变量（函数 → 配置 → 环境变量）：
 *   DASHSCOPE_KEY = sk-xxxxxxxx   （阿里云百炼 API Key）
 *   MODEL         = qwen-plus     （可选：qwen-max / qwen-turbo；A30 视觉另配 qwen-vl-max）
 *
 * 说明：百炼兼容 OpenAI 协议，直接调 compatible-mode 端点。
 * 无第三方依赖，Node.js 18 内置 fetch 直接可用。
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
};

const DASHSCOPE_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

exports.handler = async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.setStatusCode(204);
    Object.keys(CORS).forEach((k) => res.setHeader(k, CORS[k]));
    res.send('');
    return;
  }

  const path = req.path || (req.url || '/').split('?')[0] || '/';

  // 健康检查：前端状态灯用，不消耗百炼额度
  if (req.method === 'GET' && path === '/ping') {
    send(res, 200, { ok: true, ts: Date.now() });
    return;
  }
  if (req.method !== 'POST') {
    send(res, 405, { error: 'method not allowed' });
    return;
  }

  try {
    let raw = req.body;
    if (Buffer.isBuffer(raw)) raw = raw.toString('utf8');
    if (raw && typeof raw !== 'string') raw = JSON.stringify(raw);
    let body = {};
    try { body = JSON.parse(raw || '{}'); } catch (e) { body = {}; }

    const upstream = await fetch(DASHSCOPE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + process.env.DASHSCOPE_KEY,
      },
      body: JSON.stringify({
        model: process.env.MODEL || 'qwen-plus',
        messages: [
          ...(body.system ? [{ role: 'system', content: body.system }] : []),
          ...(body.messages || []),
        ],
        temperature: 0.4,
      }),
    });
    const data = await upstream.json();
    if (data && data.error) {
      send(res, 502, { error: 'dashscope: ' + (data.error.message || JSON.stringify(data.error)) });
      return;
    }
    const text = data.choices && data.choices[0] && data.choices[0].message
      ? data.choices[0].message.content : '';
    send(res, 200, { text });
  } catch (e) {
    send(res, 500, { error: String(e) });
  }
};

function send(res, status, obj) {
  res.setStatusCode(status);
  res.setHeader('Content-Type', 'application/json');
  Object.keys(CORS).forEach((k) => res.setHeader(k, CORS[k]));
  res.send(JSON.stringify(obj));
}
