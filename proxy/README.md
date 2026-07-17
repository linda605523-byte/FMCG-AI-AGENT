# LLM 代理部署指南（解决国内连不上大模型）

**背景**：`agent.linda605523.workers.dev` 在国内移动网络被 DNS 污染（解析到 Facebook/Twitter 的假 IP），导致手机端无法对话。完成后把新域名发给开发，加进前端 `LLM_ENDPOINTS` 数组第一位即可（前端已支持多端点自动故障转移）。

---

## 方案 B：阿里云函数计算 + 百炼千问（已选定 ✅）

**两条路，任选：**

### 路 1（推荐）：把两把钥匙给开发，全程代办（约 5 分钟）

1. **百炼 API Key**：登录 [阿里云百炼控制台](https://bailian.console.aliyun.com/) → 右上角头像 → API-KEY → 创建新的 API-KEY → 复制 `sk-xxx`
2. **函数计算 RAM 子账号 AccessKey**（安全，仅 FC 权限）：
   - RAM 控制台 → 用户 → 创建用户（勾选 OpenAPI 调用访问，得到 AccessKey ID + Secret）
   - 给该用户授权：仅 `AliyunFCFullAccess`（函数计算全权限）
3. 把 **百炼 Key + AccessKey ID + AccessKey Secret** 发给开发即可。开发会完成：创建函数 → 部署代码 → 配环境变量 → 联调 → 前端接入 → 验证上线

> 用完后可在 RAM 里直接禁用/删除该 AccessKey，权限即时失效。

### 路 2：自己动手（约 20 分钟）

1. 百炼控制台创建 API-KEY（同上）
2. 函数计算控制台 → 创建函数 → 「从零开始」→ 运行时 **Node.js 18** → 触发器 **HTTP 触发器**（认证方式：允许匿名访问）
3. 把 `aliyun-fc-qwen.js` 的内容粘贴为函数代码并部署
4. 函数 → 配置 → 环境变量，添加：
   - `DASHSCOPE_KEY` = 你的百炼 Key
   - `MODEL` = `qwen-plus`
5. 复制触发器的公网地址（形如 `xxx.cn-hangzhou.fcapp.run`）发给开发 ✅

**收益**：一个百炼 Key 同时覆盖 qwen-plus（对话）和 qwen-vl-max（A30 货架视觉识别），符合交接文档未决问题 10 的规划；函数计算在免费额度内成本 ≈ 0。

---

## 方案 A：Cloudflare 自定义域名（备选）

需要：① Cloudflare 账号 ② 任意域名（阿里云/腾讯云购买，.top/.xyz 首年约 10-30 元）

1. 域名接入 Cloudflare：首页 → Add a site → 输入域名 → Free 计划 → 按提示把域名 NS 改成 Cloudflare 给的地址（生效约 5-30 分钟）
2. 打开 Worker（agent.linda605523）→ Settings → Domains & Routes → Add Custom Domain → 输入 `agent.你的域名.com` → 确认
3. （可选）用 `cloudflare-worker.js` 替换 Worker 代码并 Deploy——带 `/ping` 健康检查；密钥在 Settings → Variables and Secrets 配 `DEEPSEEK_KEY`
4. 把 `agent.你的域名.com` 发给开发 ✅

---

## 对比

| | 方案 A（自定义域名） | 方案 B（阿里云 FC）✅ |
|---|---|---|
| 国内可达性 | 好 | 最好（阿里国内机房） |
| 成本 | 域名 10-30 元/年 | 免费额度内 ≈ 0 |
| 模型 | 继续 DeepSeek | 千问（百炼） |
| 后续扩展 | — | qwen-vl-max 可直接给 A30 视觉用 |
