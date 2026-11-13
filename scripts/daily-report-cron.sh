#!/usr/bin/env bash
# daily-report-cron.sh — 定时日报（cron 触发，opencode run 执行 daily-report skill）
# 退出码：0=成功 1=agent 失败 2=超时
set -u
export PATH="/home/guangbin/.opencode/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME=/home/guangbin
export TZ=Asia/Shanghai
export GIT_TERMINAL_PROMPT=0
# SSH 凭据走登录 keyring（cron 无 agent 环境 push 128 的修复，2026-11-13 实证）
export SSH_AUTH_SOCK=/run/user/1000/keyring/ssh
LOG=/tmp/opencode/daily-cron.log
mkdir -p /tmp/opencode
exec >>"$LOG" 2>&1
echo "===== $(date '+%F %T') 日报定时任务启动 ====="

cd /home/guangbin/Documents/Work || { echo "ERR: 无法 cd /home/guangbin/Documents/Work"; exit 1; }
D=$(date +%F)

# 主路径：opencode run 非交互执行 skill（深度版 + 发邮件）
# 模型固定 zai-coding-plan/glm-5.3（本地代理，避开 Kimi 5 小时配额；撞配额史见 08-27）
# 超时 15 分钟兜底（agent 偶发卡住不阻塞 cron）
# 🔴 prompt 字符串内禁用 ASCII 双引号/尖括号（会截断外层引号，"＜标题＞" 曾致整条命令被解析为重定向）
timeout 900 opencode run --auto -m zai-coding-plan/glm-5.3 \
  "执行 daily-report skill：生成 ${D} 的工作日报，落盘 /home/guangbin/Documents/Work/daily/日报-${D}.txt，并用 /home/guangbin/.dotfiles/bin/notify-owner 以「日报标题」与「正文文件路径」为参数发送（唯一发信设施，勿手搓邮件头、勿直调 msmtp）。落盘发信后必须收尾：python3 scripts/daily-index.py 重建 INDEX，git add daily/ 并 commit（docs(daily): add ${D} daily report），git push origin master 与 git push ff master（禁 force）。" \
  && { echo "[$(date '+%T')] 成功（深度版）"; exit 0; }

RC=$?
echo "[$(date '+%T')] opencode run 失败/超时(rc=$RC)，降级脚本版兜底"
# 兜底：纯 bash 档案版 + 发邮件（保证当天必有一封）
TMP=$(mktemp); : > "$TMP"
find /home/guangbin/Documents -maxdepth 3 -name ".git" 2>/dev/null | while read g; do
  case "$(dirname "$g")" in */.repo/*|*/qt5/*|*/Work__wt-*) continue;; esac
  r=$(basename "$(dirname "$g")")
  git -C "$(dirname "$g")" log --since="${D} 00:00" --until="${D} 23:59" \
    --pretty=format:"%ad|${r}|%h|%s" --date=format:"%H:%M" 2>/dev/null
done | sort >> "$TMP"
# 家目录直下仓（maxdepth 2，与 Documents 轨不重叠；排工具自管仓）
find /home/guangbin -maxdepth 2 -name ".git" 2>/dev/null | while read g; do
  r=$(basename "$(dirname "$g")")
  case "$r" in .oh-my-zsh|.nvm|.popos_shell) continue;; esac
  git -C "$(dirname "$g")" log --since="${D} 00:00" --until="${D} 23:59" \
    --pretty=format:"%ad|${r}|%h|%s" --date=format:"%H:%M" 2>/dev/null
done | sort >> "$TMP"

# __wt 工作树与母仓同 hash 去重＋归母仓名（用户裁定 2026-11-14：去重不排除）
awk -F'|' '{split($2,p,"__wt-"); $2=p[1]; if(!seen[$3]++) print $1"|"$2"|"$3"|"$4}' "$TMP" > "$TMP.d" && mv "$TMP.d" "$TMP"

REPORT="/home/guangbin/Documents/Work/daily/日报-${D}.txt"
SUBJ_TEXT="工作日报 ${D}（自动兜底版）"
if [ -s "$REPORT" ]; then
  # ponytail: 降级数据不覆盖更好的既有数据（如早前手工/深度版），只重发
  echo "[$(date '+%T')] 已存在日报（疑为深度版），兜底不覆盖，仅重发现有文件"
  SUBJ_TEXT="工作日报 ${D}（重发现有版）"
else
  {
    printf '工作日报 %s（自动兜底版）\n================================================\n\n' "$D"
    printf '【说明】agent 路径失败，此为脚本兜底档案版（按仓分组列提交）。\n\n'
    awk -F'|' '{print $2}' "$TMP" | sort | uniq -c | sort -rn | while read n r; do
      printf '### %s（%s）\n' "$r" "$n"
      grep "|${r}|" "$TMP" | awk -F'|' '{printf "  %s %s %s\n",$1,$3,$4}'
      echo
    done
  } > "$REPORT"
fi
rm -f "$TMP"

# 日报落盘即提交推送（溯源 11-03/04 漏提交；ff-only 禁 force）
python3 scripts/daily-index.py   # 兜底路径也要重建 INDEX（主路径已含，此处补漏）
git add "daily/日报-${D}.txt" daily/INDEX.md 2>/dev/null
if ! git diff --cached --quiet; then
  git commit -m "docs(daily): add ${D} daily report" \
    && git push origin master 2>/dev/null \
    && git push ff master 2>/dev/null \
    || echo "[$(date '+%T')] 提交/推送失败（日报已落盘，可事后补提交）"
fi

/home/guangbin/.dotfiles/bin/notify-owner "$SUBJ_TEXT" "$REPORT" && { echo "[$(date '+%T')] 兜底版已发"; exit 0; }
echo "[$(date '+%T')] 兜底邮件也失败"; exit 1
