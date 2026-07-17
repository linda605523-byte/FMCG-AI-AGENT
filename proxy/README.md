# LLM 代理部署指南（解决国内连不上大模型）

**背景**：`agent.linda605523.workers.dev` 在国内移动网络被 DNS 污染（解析到 Facebook/Twitter 的假 IP），导致手机端无法对话。以下两个方案任选其一，完成后把新域名发给开发，加进前端 `LLM_ENDPOINTS` 数组第一位即可（前端已支持多端点自动故障转移）。

---

## 方案 A：Cloudflare 自定义域名（约 10 分钟，推荐）

**你需要**：① Cloudflare 账号 ② 任意一个域名（没有就在阿里云/腾讯云买一个，.top/.xyz 首年约 10-30 元）

**步骤**：
1. 域名接入 Cloudflare：Cloudflare 首页 → Add a site → 输入域名 → 选 Free 计划 → 按提示去域名服务商后台把 NS 改成 Cloudflare 给的两个地址（生效约 5-30 分钟）
2. 打开现有 Worker（agent.linda605523）→ Settings → Domains & Routes → Add Custom Domain → 输入 `agent.你的域名.com` → 确认（自动签发证书，约 1 分钟生效）
3. （可选但建议）用本目录 `cloudflare-worker.js` 替换 Worker 现有代码并 Deploy——它带 `/ping` 健康检查路由，前端状态灯检测更快、不烧 DeepSeek 额度；密钥在 Settings → Variables and Secrets 配 `DEEPSEEK_KEY`
4. 把 `agent.你的域名.com` 发给开发 ✅

---

## 方案 B：阿里云函数计算 + 百炼千问（约 20 分钟，国内最稳）

**你需要**：① 阿里云账号 ② 开通「百炼」并拿到 API Key（DashScope 控制台）

**步骤**：
1. 函数计算控制台 → 创建函数 → 选「从零开始」→ 运行时 Node.js 18 → 触发器选「HTTP 触发器」（允许匿名访问）
2. 把本目录 `aliyun-fc-qwen.js` 的内容粘贴为函数代码并部署
3. 函数 → 配置 → 环境变量，添加：
   - `DASHSCOPE_KEY` = 你的百炼 Key
   - `MODEL` = `qwen-plus`（或 qwen-max）
4. 复制触发器给的公网地址（形如 `xxx.cn-hangzhou.fcapp.run`）发给开发 ✅
5. 额外收益：一个百炼 Key 同时覆盖 qwen-plus（对话）和 qwen-vl-max（A30 货架视觉识别），符合交接文档未决问题 10 的规划

---

## 两个方案怎么选

| | 方案 A（自定义域名） | 方案 B（阿里云 FC） |
|---|---|---|
| 国内可达性 | 好 | 最好（阿里国内机房） |
| 成本 | 域名 10-30 元/年 | 函数计算免费额度内 ≈ 0 |
| 模型 | 继续用 DeepSeek | 换成千问（百炼） |
| 后续扩展 | — | qwen-vl-max 可直接给 A30 用 |

> 建议：短期先用 A 把演示跑通；中期迁到 B（国内投资人演示更稳，且统一视觉/文字模型）。
