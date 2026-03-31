# 🚀 VPS 智能监控一键安装脚本

一个基于 **Bash** 的轻量级 VPS 监控脚本，支持 **异常告警**、**每日日报**、**自定义定时任务**，并可将通知推送到你的 Cloudflare Worker / TG API。

---

## ✨ 项目特色

- 🚀 一键安装，自动部署监控脚本与配置文件
- 🛠️ 交互式配置，安装过程简单直观
- ⏰ 支持自定义异常监控频率
- 📬 支持自定义每日正常播报时间
- 🔥 异常时自动告警，正常巡检静默运行
- 📊 自动采集 CPU、内存、磁盘、IOwait、Steal、Load 等指标
- 🧠 自动附带高占用进程和 Top 进程信息
- 🧪 安装完成后自动发送测试通知
- ♻️ 自动清理旧 cron 任务，避免重复添加

---

## 📦 一键安装

直接执行下面命令即可开始安装：

```bash
bash <(curl -sL https://raw.githubusercontent.com/qinglong9627/vps-daily-report/refs/heads/main/install.sh)
```

---

## 🖥️ 适用场景

这个脚本适合以下用户：

- 想轻量监控 VPS 状态的个人用户
- 不想部署 Prometheus、Zabbix、面板类监控系统的用户
- 想通过 Telegram / Worker 接口接收告警通知的用户
- 管理多台服务器，希望快速区分不同 VPS 状态的用户

---

## ⚙️ 功能说明

安装脚本会自动完成以下内容：

1. 读取你的 VPS 名称、通知地址、监控频率和日报时间
2. 写入配置文件 `/etc/vps_monitor.conf`
3. 生成核心监控脚本 `/usr/local/bin/vps_monitor.sh`
4. 自动配置 cron 定时任务
5. 自动执行一次测试通知
6. 输出安装完成信息

---

## 📊 监控内容

脚本会自动检测以下状态：

- 📈 CPU 总使用率
- 🧮 CPU `us` / `sy`
- 🐏 内存使用率
- 💾 根分区磁盘使用率
- 💽 IOwait
- 🧠 Steal
- 🌋 15 分钟系统负载
- ⏳ 系统运行时长
- 📋 Top 进程占用情况

---

## 🚨 告警规则

当前脚本默认阈值如下：

| 项目 | 默认阈值 |
|---|---|
| 🐏 内存使用率 | `> 90%` |
| 💾 磁盘使用率 | `> 90%` |
| 💽 IOwait | `> 25%` |
| 🧠 Steal | `> 10%` |
| 🌋 15 分钟负载 | `> CPU核心数 × 1.2` |
| 🔥 CPU 总使用率 | `> 85%` |
| ⚡ 高 CPU 进程判定 | `>= 20%` |

当系统没有触发异常时：

- 普通巡检模式：静默退出，不发送通知
- 每日播报模式：发送健康状态报告

---

## 🗂️ 安装后生成的文件

| 文件路径 | 说明 |
|---|---|
| `/etc/vps_monitor.conf` | 配置文件，保存 VPS 名称和通知地址 |
| `/usr/local/bin/vps_monitor.sh` | 核心监控脚本 |
| `/root/cpu_snapshot.log` | 脚本运行日志 |

---

## 🧰 环境要求

建议运行环境：

- Linux VPS
- Bash
- `cron` / `crontab`
- `curl`
- 常见系统工具：`top`、`ps`、`awk`、`sed`、`free`、`df`、`uptime`、`nproc`

可选增强依赖：

- `python3`：优先用于生成 JSON
- `jq`：在没有 `python3` 时作为备用方案

> ⚠️ 建议使用 `root` 用户执行安装，否则可能没有权限写入 `/etc` 和 `/usr/local/bin`。

---

## 🧭 安装流程

### 1️⃣ 执行安装命令

```bash
bash <(curl -sL https://raw.githubusercontent.com/qinglong9627/vps-daily-report/refs/heads/main/install.sh)
```

### 2️⃣ 按提示输入信息

安装时你需要填写：

- VPS 名称
- Cloudflare Worker URL 或 TG API 地址
- 异常监控执行频率
- 每日正常播报时间

### 3️⃣ 等待脚本自动完成部署

脚本会自动：

- 保存配置
- 写入监控脚本
- 写入 cron 定时任务
- 执行测试推送

---

## 🏷️ VPS 名称显示说明

安装时脚本会提示你输入当前 VPS 名称，例如：

```text
请输入当前 VPS 的名称 [直接回车默认使用: localhost]: Tokyo-01
```

如果你输入了 VPS 名称，例如：

```text
Tokyo-01
```

那么在通知中会显示为：

```text
⚠️ [Tokyo-01] 异常告警 [v3.4.0]
```

或者：

```text
✅ [Tokyo-01] 每日日报 [v3.4.0]
```

如果你不输入，则默认使用当前服务器的主机名（hostname）。

---

## 🔔 通知展示示例

### 🚨 异常告警示例

假设你的 VPS 名称填写的是：

```text
HK-Pro-01
```

当服务器异常时，通知可能显示为：

```text
⚠️ [HK-Pro-01] 异常告警 [v3.4.0]
--------------------------
🕒 时间: 2026-03-31 08:00:00 UTC
📊 CPU: 92% (us:71% sy:21%)
🐏 内存: 94% (1880M/2000M)
💾 磁盘: 68%
💽 IOwait: 3%   🧠 Steal: 0%
📈 Load(15m): 3.21 (阈值: 2.4)
⏳ 运行时长: 12 hours, 4 minutes
--------------------------
❌ 触发原因: 🧨 内存严重不足 (94%)
--------------------------
⚡ 高占用进程:
🔴 python3
   🆔 1234 | 👤 root | CPU: 65.3%
```

### ✅ 每日日报示例

如果系统状态正常，则可能显示为：

```text
✅ [HK-Pro-01] 每日日报 [v3.4.0]
--------------------------
🕒 时间: 2026-03-31 08:00:00 UTC
📊 CPU: 8% (us:4% sy:4%)
🐏 内存: 36% (720M/2000M)
💾 磁盘: 41%
💽 IOwait: 0%   🧠 Steal: 0%
📈 Load(15m): 0.18 (阈值: 2.4)
⏳ 运行时长: 3 days, 2 hours
--------------------------
🍃 系统各项指标正常
```

---

## ⏰ 定时任务说明

安装完成后会自动写入两条 cron：

- 一条用于异常巡检
- 一条用于每日健康播报

示例：

```cron
*/5 * * * * /usr/local/bin/vps_monitor.sh >/dev/null 2>&1
0 8 * * * /usr/local/bin/vps_monitor.sh report >/dev/null 2>&1
```

说明：

- 默认巡检模式下，仅在异常时发送通知
- `report` 模式用于每日播报
- `test` 模式用于手动测试推送

---

## 🧪 手动执行命令

### 普通巡检

```bash
/usr/local/bin/vps_monitor.sh
```

### 每日报告

```bash
/usr/local/bin/vps_monitor.sh report
```

### 测试通知

```bash
/usr/local/bin/vps_monitor.sh test
```

---

## 📝 配置文件示例

配置文件路径：

```bash
/etc/vps_monitor.conf
```

内容示例：

```bash
VPS_NAME="HK-Pro-01"
CF_WORKER_URL="https://your-worker.example.workers.dev"
```

---

## 📚 日志查看

脚本运行日志默认写入：

```bash
/root/cpu_snapshot.log
```

查看方式：

```bash
tail -f /root/cpu_snapshot.log
```

---

## 🔌 接口要求

你的通知接口需要满足：

- 支持 `POST`
- 支持 `Content-Type: application/json`
- 接收字段为 `text`
- 返回 HTTP `200` 视为发送成功

发送数据格式如下：

```json
{
  "text": "通知内容"
}
```

---

## ⚠️ 注意事项

- 请确认通知接口可以公网访问
- 请确认服务器已安装并启用 `cron`
- 建议安装完成后先执行一次测试通知
- 多台 VPS 使用时，建议给每台机器设置不同名称
- 当前消息中的时间文本带有 `UTC` 标识，实际展示仍取决于服务器本地时区配置

---

## 🧩 后续可扩展方向

你后续还可以继续增强这个脚本，例如：

- 🤖 Telegram Bot 原生推送
- 📨 飞书 / 钉钉 / 企业微信 Webhook 支持
- 💿 多磁盘挂载点检测
- 🌐 网络可达性检测
- 🧟 僵尸进程检测
- 🚫 告警去重
- 🎚️ 阈值配置化
- ⚙️ systemd 服务管理

---

## 🗑️ 卸载方法

删除定时任务并移除脚本：

```bash
crontab -l | grep -v "/usr/local/bin/vps_monitor.sh" | crontab -
rm -f /usr/local/bin/vps_monitor.sh
rm -f /etc/vps_monitor.conf
```

如需保留日志，请不要删除：

```bash
/root/cpu_snapshot.log
```

---

## 📄 License

MIT

---

## ⭐ 支持一下

如果这个项目对你有帮助，欢迎点个 **Star**。
