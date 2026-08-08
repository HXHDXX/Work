#!/usr/bin/env bash
# daily-report-cron.sh — 定时日报（cron 触发，opencode run 执行 daily-report skill）
# 退出码：0=成功 1=agent 失败 2=超时
set -u
export PATH="/home/guangbin/.opencode/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME=/home/guangbin
export TZ=Asia/Shanghai
export GIT_TERMINAL_PROMPT=0
LOG=/tmp/opencode/daily-cron.log
mkdir -p /tmp/opencode
exec >>"$LOG" 2>&1
echo "===== $(date '+%F %T') 日报定时任务启动 ====="

cd /Workspace/Work || { echo "ERR: 无法 cd /Workspace/Work"; exit 1; }
D=$(date +%F)

# 主路径：opencode run 非交互执行 skill（深度版 + 发邮件）
# 超时 15 分钟兜底（agent 偶发卡住不阻塞 cron）
timeout 900 opencode run --auto \
  "执行 daily-report skill：生成 ${D} 的工作日报，落盘 /Workspace/Work/daily/日报-${D}.txt，并发邮件到 guangbin79@icloud.com。标题用 printf|base64 生成禁止手敲。" \
  && { echo "[$(date '+%T')] 成功（深度版）"; exit 0; }

RC=$?
echo "[$(date '+%T')] opencode run 失败/超时(rc=$RC)，降级脚本版兜底"
# 兜底：纯 bash 档案版 + 发邮件（保证当天必有一封）
TMP=$(mktemp); : > "$TMP"
for root in /Workspace /HXAppPlatform; do
  find "$root" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read g; do
    case "$(dirname "$g")" in */.repo/*) continue;; esac
    r=$(basename "$(dirname "$g")")
    git -C "$(dirname "$g")" log --since="${D} 00:00" --until="${D} 23:59" \
      --pretty=format:"%ad|${r}|%h|%s" --date=format:"%H:%M" 2>/dev/null
  done
done | sort >> "$TMP"

{
  printf '工作日报 %s（自动兜底版）\n================================================\n\n' "$D"
  printf '【说明】agent 路径失败，此为脚本兜底档案版（按仓分组列提交）。\n\n'
  awk -F'|' '{print $2}' "$TMP" | sort | uniq -c | sort -rn | while read n r; do
    printf '### %s（%s）\n' "$r" "$n"
    grep "|${r}|" "$TMP" | awk -F'|' '{printf "  %s %s %s\n",$1,$3,$4}'
    echo
  done
} > "/Workspace/Work/daily/日报-${D}.txt"
rm -f "$TMP"

SUBJ=$(printf '工作日报 %s（自动兜底版）' "$D" | base64 | tr -d '\n')
{
  printf 'From: guangbin79@icloud.com\nTo: guangbin79@icloud.com\n'
  printf 'Subject: =?UTF-8?B?%s?=\n' "$SUBJ"
  printf 'MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n'
  cat "/Workspace/Work/daily/日报-${D}.txt"
} | msmtp guangbin79@icloud.com && { echo "[$(date '+%T')] 兜底版已发"; exit 0; }
echo "[$(date '+%T')] 兜底邮件也失败"; exit 1
