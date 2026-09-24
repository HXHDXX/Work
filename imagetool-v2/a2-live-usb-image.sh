#!/bin/bash
# =============================================================================
# a2-live-usb-image.sh —— 路线 A2：Live U 盘冷读（车机 Live 环境里运行）
# 功能: 整盘只读镜像 → 经 ssh 推送到工作站（或落第二块 U 盘/移动硬盘）
# 用法: sudo bash a2-live-usb-image.sh kylin@<工作站IP>:/Workspace/Work/outputs/golden-images
#    或: sudo bash a2-live-usb-image.sh /media/usb-target   （本地落盘模式）
# 前提: 从 arm64 Live U 盘启动；设备盘 /dev/sda 未挂载（或已 umount）
# 教训对应: L4(原方案本意) L2(不再碰运行中的系统)
# =============================================================================
set -euo pipefail
bash -n "$0" || { echo "[FATAL] 脚本自身语法错误，拒绝执行"; exit 9; }
DEST=${1:?用法: a2-live-usb-image.sh user@host:/远程目录  或  /本地挂载目录}
DEV=${DEV:-/dev/sda}
[ "$(id -u)" -eq 0 ] || { echo "[FATAL] 须 root"; exit 1; }
command -v pigz >/dev/null || { echo "[FATAL] Live 环境缺 pigz（apt/dnf 安装或改用 gzip，编辑本行）"; exit 1; }

# ---------- 安全检查 ----------
MODEL=$(lsblk -ndo MODEL "$DEV" 2>/dev/null || echo unknown)
SIZE=$(lsblk -ndbo SIZE "$DEV" 2>/dev/null || echo 0)
echo "[check] 源盘: $DEV model=$MODEL size=$SIZE"
echo "$MODEL" | grep -q "${EXPECT_MODEL:-MasonSemi}" || { echo "[FATAL] 型号不匹配"; exit 2; }
if lsblk -nrpo MOUNTPOINTS "$DEV"?* 2>/dev/null | grep -q '^/'; then
  echo "[check] 检测到已挂载分区，尝试只读重挂..."
  for m in $(lsblk -nrpo NAME,MOUNTPOINTS "$DEV"?* 2>/dev/null | awk '$2 ~ /^\//{print $2}'); do
    mount -o remount,ro "$m" || { echo "[FATAL] 无法只读化 $m，请手动 umount"; exit 2; }
  done
fi
STAMP=$(date +%Y%m%d-%H%M)
NAME="kylin-v10-arm64-golden-$STAMP.img.gz"

# ---------- 镜像 ----------
echo "[image] dd|pigz → $DEST/$NAME （源盘 953.9G，读+压 1~2 小时）"
sync
set +e
if [[ "$DEST" == *:* ]]; then   # 远程模式 user@host:/dir
  dd if="$DEV" bs=8M iflag=fullblock status=progress | pigz -1 -p6 \
    | ssh -o StrictHostKeyChecking=no "${DEST%%:*}" "cat > ${DEST#*:}/$NAME"
  RC=${PIPESTATUS[0]}/${PIPESTATUS[2]}
else                            # 本地模式
  dd if="$DEV" bs=8M iflag=fullblock status=progress | pigz -1 -p6 > "$DEST/$NAME"
  RC=${PIPESTATUS[0]}/${PIPESTATUS[1]}
fi
set -e
echo "[done] rc=$RC expect_bytes=$SIZE —— 校验命令（工作站上执行）:"
echo "  pigz -dc $DEST/$NAME | wc -c        # 应等于 $SIZE"
echo "  sha256sum $DEST/$NAME"
[ "$RC" = "0/0" ] || { echo "[FATAL] 传输失败 rc=$RC"; exit 4; }
echo "[note] 封版提醒: 若母版在本次成像前重启过，需先重跑 prep_for_image.sh（标记会被吃掉）"
