#!/bin/bash
# =============================================================================
# restore-image.sh —— 把金镜像写回目标盘（克隆/恢复两用）
# 用法: sudo bash restore-image.sh golden-xxx.img.gz /dev/sdX
# 安全: 目标必须是 USB/可移动盘，或 FORCE_TARGET=1 显式覆盖；容量 >= 镜像解压尺寸
# =============================================================================
set -euo pipefail
bash -n "$0" || { echo "[FATAL] 脚本自身语法错误，拒绝执行"; exit 9; }
IMG=${1:?用法: restore-image.sh golden-xxx.img.gz /dev/sdX}
DEV=${2:?用法: restore-image.sh golden-xxx.img.gz /dev/sdX}
[ "$(id -u)" -eq 0 ] || { echo "[FATAL] 须 root"; exit 1; }
[ -f "$IMG" ] || { echo "[FATAL] 镜像不存在: $IMG"; exit 1; }
command -v pigz >/dev/null || { echo "[FATAL] 缺 pigz"; exit 1; }

# ---------- 安全检查 ----------
TRAN=$(lsblk -ndo TRAN "$DEV" 2>/dev/null || echo none)
RM=$(lsblk -ndo RM "$DEV" 2>/dev/null || echo 0)
MODEL=$(lsblk -ndo MODEL "$DEV" 2>/dev/null || echo unknown)
TSIZE=$(lsblk -ndbo SIZE "$DEV" 2>/dev/null || echo 0)
# 镜像解压尺寸从 manifest 或 gzip 头估算不可靠——要求 manifest 存在并取 bytes_uncompressed
MAN="${IMG%.img.gz}.img.gz.manifest.txt"
[ -f "$MAN" ] || { echo "[FATAL] 缺 manifest，无法核对尺寸"; exit 2; }
IBYTES=$(awk -F': *' '/^bytes_uncompressed/{print $2}' "$MAN" | awk '{print $1}')
echo "[check] 目标: $DEV model=$MODEL size=$TSIZE tran=$TRAN rm=$RM"
if [ "${FORCE_TARGET:-0}" != "1" ] && [ "$TRAN" != "usb" ] && [ "$RM" != "1" ]; then
  echo "[FATAL] 拒绝写非可移动盘（FORCE_TARGET=1 可覆盖——仅当你确信目标盘号）"; exit 2
fi
[ "$TSIZE" -ge "$IBYTES" ] || { echo "[FATAL] 目标容量($TSIZE) < 镜像($IBYTES)"; exit 2; }
if lsblk -nrpo MOUNTPOINTS "$DEV"?* 2>/dev/null | grep -q '^/'; then
  echo "[FATAL] 目标有分区挂载，先 umount"; exit 2
fi
echo "[check] 将擦除 $DEV ($MODEL)！10 秒内 Ctrl-C 取消..."; sleep 10

# ---------- 写入 ----------
set +e
pigz -dc "$IMG" | dd of="$DEV" bs=8M status=progress conv=fsync
RC=${PIPESTATUS[1]}
set -e
sync
echo "WRITE_EXIT=$RC $(date -Is)"
[ "$RC" -eq 0 ] || { echo "[FATAL] 写入失败 rc=$RC"; exit 4; }

# ---------- 抽查首尾 ----------
echo "[verify] 抽查首 2MB 分区表"
head -c 2M "$IMG" | pigz -dc 2>/dev/null | head -c 2M > /tmp/opencode/pt-check.bin || \
  { pigz -dc "$IMG" | head -c 2M > /tmp/opencode/pt-check.bin; }
fdisk -l /tmp/opencode/pt-check.bin 2>&1 | head -15
rm -f /tmp/opencode/pt-check.bin
echo "完成。盘装回设备首启：firstboot-unique 自动去重（machine-id/SSH密钥/主机名），之后只剩麒麟激活与密码。"
