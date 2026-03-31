#!/bin/bash

# =====================================================
# VPS 智能监控一键安装脚本 (支持自定义定时任务)
# =====================================================

# 定义颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 定义安装路径
CONFIG_FILE="/etc/vps_monitor.conf"
SCRIPT_FILE="/usr/local/bin/vps_monitor.sh"

echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}      欢迎使用 VPS 智能监控一键安装脚本      ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ---------------------------------------------------
# 1. 交互式获取配置
# ---------------------------------------------------
# [1.1] 获取 VPS_NAME
DEFAULT_HOSTNAME=$(hostname)
read -p "请输入当前 VPS 的名称 [直接回车默认使用: $DEFAULT_HOSTNAME]: " INPUT_VPS_NAME
VPS_NAME=${INPUT_VPS_NAME:-$DEFAULT_HOSTNAME}

# [1.2] 获取 API URL
echo -e "\n${YELLOW}请输入 Cloudflare Worker URL 或 TG API 地址:${NC}"
echo -e "(例如: https://my-notify-bot.abc.workers.dev)"
read -p "URL: " CF_WORKER_URL

while [ -z "$CF_WORKER_URL" ]; do
    echo -e "${RED}URL 不能为空，请重新输入!${NC}"
    read -p "URL: " CF_WORKER_URL
done

# [1.3] 设置监控执行频率
echo -e "\n${YELLOW}请设置【异常监控】的执行频率:${NC}"
echo "1) 按分钟执行 (例如: 每 5 分钟检测一次)"
echo "2) 按小时执行 (例如: 每 2 小时检测一次)"
read -p "请选择模式 [1/2, 默认 1]: " MON_UNIT_CHOICE

if [ "$MON_UNIT_CHOICE" == "2" ]; then
    while true; do
        read -p "请输入每隔几小时执行一次 [1-23, 默认 1]: " MON_VAL
        MON_VAL=${MON_VAL:-1}
        if [[ "$MON_VAL" =~ ^[0-9]+$ ]] && [ "$MON_VAL" -ge 1 ] && [ "$MON_VAL" -le 23 ]; then
            CRON_MON="0 */${MON_VAL} * * *"
            MON_DESC="每 ${MON_VAL} 小时"
            break
        else
            echo -e "${RED}输入无效，请输入 1-23 之间的数字！${NC}"
        fi
    done
else
    while true; do
        read -p "请输入每隔几分钟执行一次 [1-59, 默认 5]: " MON_VAL
        MON_VAL=${MON_VAL:-5}
        if [[ "$MON_VAL" =~ ^[0-9]+$ ]] && [ "$MON_VAL" -ge 1 ] && [ "$MON_VAL" -le 59 ]; then
            CRON_MON="*/${MON_VAL} * * * *"
            MON_DESC="每 ${MON_VAL} 分钟"
            break
        else
            echo -e "${RED}输入无效，请输入 1-59 之间的数字！${NC}"
        fi
    done
fi

# [1.4] 设置每日播报时间
echo -e "\n${YELLOW}请设置【每日正常播报】的推送时间 (24小时制服务器时间):${NC}"
while true; do
    read -p "请输入小时 [0-23, 默认 8]: " REPORT_HOUR
    REPORT_HOUR=${REPORT_HOUR:-8}
    if [[ "$REPORT_HOUR" =~ ^[0-9]+$ ]] && [ "$REPORT_HOUR" -ge 0 ] && [ "$REPORT_HOUR" -le 23 ]; then
        break
    else
        echo -e "${RED}输入无效，请输入 0-23 之间的数字！${NC}"
    fi
done

while true; do
    read -p "请输入分钟 [0-59, 默认 0]: " REPORT_MIN
    REPORT_MIN=${REPORT_MIN:-0}
    if [[ "$REPORT_MIN" =~ ^[0-9]+$ ]] && [ "$REPORT_MIN" -ge 0 ] && [ "$REPORT_MIN" -le 59 ]; then
        break
    else
        echo -e "${RED}输入无效，请输入 0-59 之间的数字！${NC}"
    fi
done

CRON_REPORT="${REPORT_MIN} ${REPORT_HOUR} * * *"
# 补齐格式（比如 8:0 变成 08:00）方便展示
REPORT_DESC=$(printf "每天 %02d:%02d" "$REPORT_HOUR" "$REPORT_MIN")

# ---------------------------------------------------
# 2. 保存配置文件
# ---------------------------------------------------
echo -e "\n${CYAN}[1/4] 正在保存配置文件到 ${CONFIG_FILE}...${NC}"
cat > "$CONFIG_FILE" << EOF
# VPS 监控脚本配置文件
VPS_NAME="$VPS_NAME"
CF_WORKER_URL="$CF_WORKER_URL"
EOF

# ---------------------------------------------------
# 3. 生成核心监控脚本 (代码保持不变)
# ---------------------------------------------------
echo -e "${CYAN}[2/4] 正在生成核心监控脚本到 ${SCRIPT_FILE}...${NC}"

# 注意：这里的 'EOF' 必须带单引号！
cat > "$SCRIPT_FILE" << 'EOF'
#!/bin/bash
# ================= VPS 智能监控脚本 =================
VERSION="3.4.0"

################ 读取外部配置 ################
if [ -f "/etc/vps_monitor.conf" ]; then
    source /etc/vps_monitor.conf
else
    echo "配置文件 /etc/vps_monitor.conf 不存在！"
    exit 1
fi

################ 统一日志系统 ################
LOG_FILE="/root/cpu_snapshot.log"
exec >> "$LOG_FILE" 2>&1
echo "================ $(date '+%Y-%m-%d %H:%M:%S') ================"
echo "VPS Monitor Script v${VERSION} Start"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C

################ 配置区域 ################
TOP_N=5
HIGH_CPU_PROC=20
TOTAL_CPU_THRESH=85
IOWAIT_THRESH=25
STEAL_THRESH=10
MEM_THRESH=90
DISK_THRESH=90

CPU_CORES=$(nproc)
LOAD_THRESH=$(awk -v cores="$CPU_CORES" 'BEGIN { print cores * 1.2 }')

################ 模式判断 ################
HEALTH_MODE=0
if [[ "$1" == "report" ]] || [[ "$1" == "test" ]]; then
    HEALTH_MODE=1
fi

################ CPU 获取 ################
CPU_INFO=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -n1)
CPU_INFO_CLEAN=$(echo "$CPU_INFO" | sed 's/,/ /g')

get_cpu_val() {
    echo "$CPU_INFO_CLEAN" | awk -v label="$1" '{for(i=1;i<=NF;i++) if ($i==label) print $(i-1)}' | cut -d. -f1
}

US=$(get_cpu_val "us")
SY=$(get_cpu_val "sy")
ID=$(get_cpu_val "id")
WA=$(get_cpu_val "wa")
ST=$(get_cpu_val "st")

US=${US:-0}; SY=${SY:-0}; ID=${ID:-0}; WA=${WA:-0}; ST=${ST:-0}
TOTAL_CPU=$((100 - ID))

################ Load / 内存 / 磁盘 ################
LOAD_15M=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f3 | xargs)
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_RATE=$(( MEM_USED * 100 / MEM_TOTAL ))
DISK_RATE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)

################ 异常判断 ################
ALERT_REASON=""
IS_LOAD_HIGH=$(awk -v l="$LOAD_15M" -v t="$LOAD_THRESH" 'BEGIN {print (l > t) ? 1 : 0}')

if (( MEM_RATE > MEM_THRESH )); then
    ALERT_REASON="🧨 内存严重不足 (${MEM_RATE}%)"
elif (( DISK_RATE > DISK_THRESH )); then
    ALERT_REASON="💾 磁盘空间不足 (${DISK_RATE}%)"
elif (( WA > IOWAIT_THRESH )); then
    ALERT_REASON="🚨 磁盘IO瓶颈 (${WA}%)"
elif (( ST > STEAL_THRESH )); then
    ALERT_REASON="⚠️ CPU被宿主机抢占 (${ST}%)"
elif (( IS_LOAD_HIGH == 1 )); then
    ALERT_REASON="🌋 系统负载过高 (${LOAD_15M})"
elif (( TOTAL_CPU > TOTAL_CPU_THRESH )); then
    ALERT_REASON="🔥 CPU使用率过高 (${TOTAL_CPU}%)"
fi

################ 静默退出 ################
if [ "$HEALTH_MODE" -eq 0 ] && [ -z "$ALERT_REASON" ]; then
    echo "No alert triggered. Exit silently."
    exit 0
fi

NL=$'\n'

################ 构建通知 ################
if [ "$HEALTH_MODE" -eq 1 ] && [ -z "$ALERT_REASON" ]; then
    MSG="✅ [${VPS_NAME}] 每日日报 [v${VERSION}]${NL}"
else
    MSG="⚠️ [${VPS_NAME}] 异常告警 [v${VERSION}]${NL}"
fi

MSG+="--------------------------${NL}"
MSG+="🕒 时间: $(date '+%Y-%m-%d %H:%M:%S') UTC${NL}"
MSG+="📊 CPU: ${TOTAL_CPU}% (us:${US}% sy:${SY}%)${NL}"
MSG+="🐏 内存: ${MEM_RATE}% (${MEM_USED}M/${MEM_TOTAL}M)${NL}"
MSG+="💾 磁盘: ${DISK_RATE}%${NL}"
MSG+="💽 IOwait: ${WA}%   🧠 Steal: ${ST}%${NL}"
MSG+="📈 Load(15m): ${LOAD_15M} (阈值: ${LOAD_THRESH})${NL}"

UPTIME=$(uptime -p | sed 's/up //')
MSG+="⏳ 运行时长: ${UPTIME}${NL}"
MSG+="--------------------------${NL}"

if [ -n "$ALERT_REASON" ]; then
    MSG+="❌ 触发原因: ${ALERT_REASON}${NL}"
else
    MSG+="🍃 系统各项指标正常${NL}"
fi
MSG+="--------------------------${NL}"

################ Top 进程分析 ################
CPU_RAW=$(ps -Ao user,pid,pcpu,comm --sort=-pcpu | head -n $((TOP_N+1)) | tail -n $TOP_N)

HIGH_CPU_TEXT=""
OTHER_CPU_TEXT=""

while read -r USER PID CPU CMD; do
    CPU_INT=${CPU%.*}
    USER_SHORT=${USER:0:8}
    INFO_STR="   🆔 ${PID} | 👤 ${USER_SHORT} | CPU: ${CPU}%"

    if [ "$CPU_INT" -ge "$HIGH_CPU_PROC" ]; then
        HIGH_CPU_TEXT+="${NL}🔴 ${CMD}${NL}${INFO_STR}${NL}"
    else
        OTHER_CPU_TEXT+="${NL}🔹 ${CMD} -> ${CPU}%${NL}"
    fi
done <<< "$CPU_RAW"

if [ -n "$HIGH_CPU_TEXT" ]; then
    MSG+="⚡ 高占用进程:${NL}"
    MSG+="${HIGH_CPU_TEXT}"
    MSG+="${NL}--------------------------${NL}"
fi

if [ -n "$OTHER_CPU_TEXT" ]; then
    MSG+="📋 Top ${TOP_N} 进程:${NL}"
    MSG+="${OTHER_CPU_TEXT}"
fi

################ JSON 处理 ################
if command -v python3 >/dev/null 2>&1; then
    JSON_PAYLOAD=$(python3 -c "import json,sys;print(json.dumps({'text':sys.argv[1]}))" "$MSG")
elif command -v jq >/dev/null 2>&1; then
    JSON_PAYLOAD=$(jq -n --arg text "$MSG" '{text:$text}')
else
    ESCAPED_MSG=$(echo -n "$MSG" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    JSON_PAYLOAD="{\"text\":\"$ESCAPED_MSG\"}"
fi

################ 发送 ################
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 -X POST "$CF_WORKER_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Report sent successfully. HTTP $HTTP_CODE"
else
    echo "Report FAILED. HTTP $HTTP_CODE"
fi

echo "Script finished."
EOF

# 赋予执行权限
chmod +x "$SCRIPT_FILE"

# ---------------------------------------------------
# 4. 设置自定义定时任务 (Crontab)
# ---------------------------------------------------
echo -e "${CYAN}[3/4] 正在配置定时任务...${NC}"

# 清除旧的相关的 cron，防止重复添加
crontab -l 2>/dev/null | grep -v "$SCRIPT_FILE" > /tmp/current_cron

# 添加新任务：使用用户自定义的时间
echo "${CRON_MON} $SCRIPT_FILE >/dev/null 2>&1" >> /tmp/current_cron
echo "${CRON_REPORT} $SCRIPT_FILE report >/dev/null 2>&1" >> /tmp/current_cron

crontab /tmp/current_cron
rm -f /tmp/current_cron

echo -e "${GREEN}定时任务已添加：${NC}"
echo -e " - 异常监控: ${YELLOW}${MON_DESC}${NC} 执行一次 (${CRON_MON})"
echo -e " - 每日播报: ${YELLOW}${REPORT_DESC}${NC} 执行一次 (${CRON_REPORT})"

# ---------------------------------------------------
# 5. 执行测试
# ---------------------------------------------------
echo -e "\n${CYAN}[4/4] 正在执行测试发送通知...${NC}"
$SCRIPT_FILE test

echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}   ✅ 安装与配置全部完成！${NC}"
echo -e "   VPS 名称:   ${YELLOW}$VPS_NAME${NC}"
echo -e "   监控频率:   ${YELLOW}${MON_DESC}${NC}"
echo -e "   播报时间:   ${YELLOW}${REPORT_DESC}${NC}"
echo -e "   监控脚本:   ${YELLOW}$SCRIPT_FILE${NC}"
echo -e "   配置文件:   ${YELLOW}$CONFIG_FILE${NC}"
echo -e "${GREEN}=================================================${NC}"
