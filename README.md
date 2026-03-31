# VPS 智能监控一键安装脚本

一个基于 Bash 的 VPS 监控与通知脚本，一键安装、自动配置、支持自定义定时任务，可将服务器异常告警和每日运行状态推送到你的通知接口。

## 项目简介

这个脚本用于在 Linux VPS 上快速部署一套轻量级监控方案。  
安装后会自动生成监控脚本、写入配置文件、配置定时任务，并立即发送一次测试通知。

它适合以下场景：

- 个人 VPS 日常运维
- 多台服务器健康状态巡检
- 通过 Cloudflare Worker / TG API 接收告警消息
- 不想部署复杂监控面板，只想要轻量通知方案的用户

## 功能特性

- 一键安装，自动完成配置文件、监控脚本和定时任务部署
- 支持交互式输入 VPS 名称和通知接口地址
- 支持自定义异常监控频率
- 支持自定义每日正常播报时间
- 异常时自动推送告警，正常情况下静默运行
- 支持每日健康日报推送
- 自动采集 CPU、内存、磁盘、IOwait、Steal、Load、运行时长等指标
- 自动附带 Top 进程信息，方便快速排查问题
- 安装完成后自动执行一次测试通知
- 自动清理旧的同类 cron 任务，避免重复添加

## 监控内容

脚本会检测以下系统状态：

- CPU 总使用率
- CPU `us` / `sy`
- 内存使用率
- 根分区磁盘使用率
- IOwait
- Steal
- 15 分钟系统负载
- 系统运行时长
- Top N 进程占用情况

## 告警规则

当前脚本内置的默认阈值如下：

| 指标 | 阈值 |
|---|---|
| 内存使用率 | `> 90%` |
| 磁盘使用率 | `> 90%` |
| IOwait | `> 25%` |
| Steal | `> 10%` |
| 15 分钟负载 | `> CPU核心数 × 1.2` |
| CPU 总使用率 | `> 85%` |
| 高 CPU 进程判定 | `>= 20%` |

当系统未触发异常时：

- 普通巡检模式下静默退出，不发送通知
- 每日播报模式下发送健康状态消息

## 安装后生成的文件

脚本会生成以下文件：

| 路径 | 说明 |
|---|---|
| `/etc/vps_monitor.conf` | 配置文件，保存 VPS 名称和通知接口地址 |
| `/usr/local/bin/vps_monitor.sh` | 核心监控脚本 |
| `/root/cpu_snapshot.log` | 运行日志文件 |

## 运行环境要求

建议在以下环境中使用：

- Linux VPS
- Bash
- `cron` / `crontab`
- `curl`
- 常见系统工具：`top`、`ps`、`awk`、`sed`、`free`、`df`、`uptime`、`nproc`

可选增强依赖：

- `python3`：优先用于构造 JSON
- `jq`：当没有 `python3` 时可作为备用方案

> 建议使用 root 用户执行安装脚本，否则可能没有权限写入 `/etc` 和 `/usr/local/bin`。

## 使用方法

### 1. 保存脚本

将安装脚本保存为：

```bash
install_vps_monitor.sh
```

### 2. 授权执行

```bash
chmod +x install_vps_monitor.sh
```

### 3. 运行安装

```bash
sudo bash install_vps_monitor.sh
```

### 4. 按提示完成配置

安装过程中会让你输入：

- 当前 VPS 名称
- Cloudflare Worker URL 或 TG API 地址
- 异常监控执行频率
- 每日正常播报时间

## 交互配置说明

### VPS 名称

如果你直接回车，默认会使用当前服务器的 `hostname`。

### 通知地址

你需要提供一个可接收 `POST` JSON 的接口地址，例如：

```text
https://your-worker.example.workers.dev
```

脚本发送的数据格式为：

```json
{
  "text": "通知内容"
}
```

### 异常监控频率

支持两种模式：

- 按分钟执行，例如每 5 分钟一次
- 按小时执行，例如每 2 小时一次

### 每日播报时间

你可以设置每天固定时间发送一次系统健康日报。  
时间使用服务器本地时间的 24 小时制。

## 定时任务说明

安装完成后，脚本会自动写入两条 cron：

- 一条用于异常巡检
- 一条用于每日正常播报

示例：

```cron
*/5 * * * * /usr/local/bin/vps_monitor.sh >/dev/null 2>&1
0 8 * * * /usr/local/bin/vps_monitor.sh report >/dev/null 2>&1
```

其中：

- 普通模式：仅在触发异常时推送
- `report` 模式：每日定时发送健康播报
- `test` 模式：安装完成后立即测试推送一次

## 手动执行命令

### 普通巡检

```bash
/usr/local/bin/vps_monitor.sh
```

### 发送每日报告

```bash
/usr/local/bin/vps_monitor.sh report
```

### 测试通知

```bash
/usr/local/bin/vps_monitor.sh test
```

## 推送消息内容

通知消息通常包含以下信息：

- VPS 名称
- 脚本版本号
- 当前时间
- CPU 使用率
- 内存使用率
- 磁盘使用率
- IOwait / Steal
- Load(15m)
- 系统运行时长
- 异常触发原因
- 高占用进程 / Top 进程列表

## 告警示例

### 异常告警示例

```text
⚠️ [MyVPS] 异常告警 [v3.4.0]
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

### 每日播报示例

```text
✅ [MyVPS] 每日日报 [v3.4.0]
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

## 脚本工作流程

安装脚本执行过程如下：

1. 读取用户输入的 VPS 名称、通知地址、巡检频率和日报时间
2. 写入配置文件 `/etc/vps_monitor.conf`
3. 生成核心监控脚本 `/usr/local/bin/vps_monitor.sh`
4. 配置 cron 定时任务
5. 执行一次测试通知
6. 输出安装完成信息

## 配置文件示例

```bash
VPS_NAME="my-vps"
CF_WORKER_URL="https://your-worker.example.workers.dev"
```

## 日志说明

核心脚本运行日志会追加写入：

```bash
/root/cpu_snapshot.log
```

你可以使用下面的命令查看：

```bash
tail -f /root/cpu_snapshot.log
```

## 适用接口要求

你的通知接口需要满足以下条件：

- 支持 `POST`
- 支持 `Content-Type: application/json`
- 接收字段为 `text`
- 返回 HTTP `200` 视为发送成功

## 注意事项

- 请确认目标接口可公网访问
- 请确认服务器已安装并启用 `cron`
- 建议先手动执行一次 `test` 模式确认通知链路正常
- 如果你有多个 VPS，建议给每台机器设置不同的 `VPS_NAME`
- 当前脚本的“时间”显示文本中标注了 `UTC`，但实际取值依赖服务器本地时区，使用前建议自行确认时区设置是否符合你的需求

## 可优化方向

如果你后续还想继续升级这个脚本，可以考虑增加：

- Telegram Bot 原生推送
- 飞书 / 钉钉 / 企业微信 Webhook 支持
- 多磁盘挂载点检测
- 网络连通性检测
- 自动检测僵尸进程
- 历史告警去重
- 阈值可配置化
- systemd service 管理

## 卸载方法

如需卸载，可以手动执行：

```bash
crontab -l | grep -v "/usr/local/bin/vps_monitor.sh" | crontab -
rm -f /usr/local/bin/vps_monitor.sh
rm -f /etc/vps_monitor.conf
```

如需保留日志，请不要删除：

```bash
/root/cpu_snapshot.log
```

## License

MIT

---

如果这个项目对你有帮助，欢迎 Star。
