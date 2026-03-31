# 🚀 SSH-Telegram-Gatekeeper

一个部署在 **Cloudflare Workers** 上的 Telegram 消息中转 Worker。  
它可以接收外部 `POST` 请求，将消息转发到 Telegram，并支持 **IP / 地区白名单** 控制；未授权访问时返回自定义拦截页。

---

## ✨ 功能特性

- 📩 接收外部 JSON 请求并转发到 Telegram
- 🔐 支持 IP 白名单访问控制
- 🌍 支持国家 / 城市白名单访问控制
- 🚫 未授权请求返回自定义 403 拦截页
- 🪵 支持 Worker 日志输出
- 🧼 日志中自动脱敏部分敏感字段
- 🎭 文本预览最多保留前 11 行
- 🐏 内存字段可在日志预览中伪装显示

---

## 📦 使用场景

适合以下场景：

- VPS 监控脚本消息转发到 Telegram
- 自建通知网关
- 简单的 Telegram Push API 中转
- 给公开接口增加基础访问控制

---

## 🧰 环境要求

- Cloudflare 账号
- 已开通 Workers
- 一个 Telegram Bot
- 你的 Telegram 用户 ID 或群组 ID
- Wrangler（可选，用于本地部署）

---

## 🔑 需要配置的环境变量

在 Cloudflare Worker 中配置以下变量：

| 变量名 | 必填 | 说明 |
|---|---|---|
| `TG_BOT_TOKEN` | 是 | Telegram Bot Token |
| `TG_USER_ID` | 是 | Telegram 用户 ID 或群组 ID |
| `ALLOWED_IPS` | 否 | 允许访问的 IP / CIDR / 前缀通配规则，多个用逗号分隔 |
| `ALLOWED_LOCATIONS` | 否 | 允许访问的国家或国家:城市规则，多个用逗号分隔 |

---

## 📝 白名单规则说明

### `ALLOWED_IPS` 示例

```text
1.2.3.4
1.2.3.*
1.2.3.0/24
8.8.8.8, 1.2.3.*, 10.0.0.0/8
```

支持：

- 单个 IP
- 星号前缀匹配
- CIDR 网段
- 多规则逗号分隔

### `ALLOWED_LOCATIONS` 示例

```text
singapore
hong kong
japan:tokyo
singapore, japan:tokyo
```

支持：

- 仅国家
- 国家 + 城市
- 多规则逗号分隔

---

## 🚀 部署方式

### 方法一：Cloudflare Dashboard

1. 登录 Cloudflare
2. 进入 **Workers & Pages**
3. 创建一个 Worker
4. 将代码粘贴进去
5. 在 **Settings / Variables** 中添加环境变量
6. 部署

### 方法二：Wrangler

安装 Wrangler：

```bash
npm install -g wrangler
```

初始化项目后，把代码保存为 `src/index.js`，再部署：

```bash
wrangler deploy
```

---

## 🔧 请求方式

该 Worker 只接受 `POST` 请求，且请求体必须是 JSON。

请求示例：

```bash
curl -X POST "https://your-worker.your-subdomain.workers.dev" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello from Worker"}'
```

请求体格式：

```json
{
  "text": "要发送到 Telegram 的消息"
}
```

---

## ✅ 成功响应

如果 Telegram 发送成功，Worker 会返回 Telegram 官方接口返回的 JSON 结果，HTTP 状态码为：

```text
200
```

---

## ❌ 异常响应

可能返回的状态码：

| 状态码 | 说明 |
|---|---|
| `400` | 请求体不是合法 JSON |
| `403` | IP 或地区不在允许范围内 |
| `405` | 请求方法不是 POST |
| `500` | Telegram API 返回失败 |
| `502` | Worker 无法连接 Telegram API |

---

## 🔒 与 VPS 监控脚本对接

如果你的 VPS 脚本发送的是：

```json
{
  "text": "监控消息内容"
}
```

并且请求头是：

```text
Content-Type: application/json
```

那么可以直接对接使用。

例如：

```bash
CF_WORKER_URL="https://your-worker.your-subdomain.workers.dev"
```

VPS 脚本把消息 POST 到这个地址后，Worker 会自动转发到 Telegram。

---

## 🖥️ 拦截逻辑说明

当请求来源不在白名单内时，Worker 会：

- 记录一条拦截日志
- 返回自定义 403 页面
- 页面中展示脱敏后的 IP 和来源地区
- 不执行 Telegram 转发

---

## 🪵 日志说明

Worker 会输出两类日志：

- 拦截非法访问时的日志
- Telegram 成功 / 失败时的日志

日志中会尽量脱敏，例如：

- IP 仅保留前两段
- Telegram ID 做部分掩码处理
- 文本预览最多只保留前 11 行

---

## ⚠️ 注意事项

- 不要把 `TG_BOT_TOKEN` 提交到 GitHub
- 不要把真实 `TG_USER_ID`、白名单 IP 直接写进源码
- 如果配置了白名单，记得把你的 VPS 出口 IP 或所在地加入允许列表
- 如果你使用 Telegram 群组，请确认 Bot 已加入群组并具备发言权限

---

## 📄 License

MIT
