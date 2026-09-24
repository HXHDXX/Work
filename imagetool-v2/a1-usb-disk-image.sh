#!/bin/bash
# =============================================================================
# a1-usb-disk-image.sh —— 路线 A1：拆盘直读（工作站上运行）
# 功能: [修ESP] + [恢复封版标记] + 整盘镜像(dd|pigz) + 自动校验 + manifest
# 用法: sudo bash a1-usb-disk-image.sh /dev/sdX [--no-fix-esp] [--no-seal]
# 覆盖期望值(谨慎): EXPECT_MODEL=... EXPECT_SIZE=... sudo bash ...
# 教训对应: L1(解冻路径独立,A1无需冻结) L4(零修改) 脚本先 bash -n 自检
# =============================================================================
set -euo pipefail
bash -n "$0" || { echo "[FATAL] 脚本自身语法错误，拒绝执行"; exit 9; }

DEV=${1:?用法: a1-usb-disk-image.sh /dev/sdX [--no-fix-esp] [--no-seal]}
FIX_ESP=1; SEAL=1
for a in "${@:2}"; do
  case "$a" in
    --no-fix-esp) FIX_ESP=0 ;;
    --no-seal)    SEAL=0 ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
done
[ "$(id -u)" -eq 0 ] || { echo "[FATAL] 须 root"; exit 1; }
command -v pigz >/dev/null || { echo "[FATAL] 缺 pigz"; exit 1; }

DEST_DIR=${DEST_DIR:-/Workspace/Work/outputs/golden-images}
mkdir -p "$DEST_DIR"
STAMP=$(date +%Y%m%d-%H%M)
IMG="$DEST_DIR/kylin-v10-arm64-golden-$STAMP.img.gz"
LOG="${IMG}.log"

# ---------- 安全检查（写盘级操作前三重核验） ----------
TRAN=$(lsblk -ndo TRAN "$DEV" 2>/dev/null || echo none)
MODEL=$(lsblk -ndo MODEL "$DEV" 2>/dev/null || echo unknown)
SIZE=$(lsblk -ndbo SIZE "$DEV" 2>/dev/null || echo 0)
echo "[check] 目标: dev=$DEV model=$MODEL size=$SIZE tran=$TRAN"
[ "$TRAN" = "usb" ] || { echo "[FATAL] 拒绝: 非 USB 总线设备（防止误碰本机盘）"; exit 2; }
EXPECT_MODEL=${EXPECT_MODEL:-MasonSemi}
EXPECT_SIZE=${EXPECT_SIZE:-1024209543168}
echo "$MODEL" | grep -q "$EXPECT_MODEL" || { echo "[FATAL] 型号不匹配: $MODEL ≠ *$EXPECT_MODEL*"; exit 2; }
[ "$SIZE" = "$EXPECT_SIZE" ] || { echo "[FATAL] 容量不匹配: $SIZE ≠ $EXPECT_SIZE"; exit 2; }
if lsblk -nrpo MOUNTPOINTS "$DEV"?* 2>/dev/null | grep -q '^/'; then
  echo "[FATAL] 拒绝: 目标有分区已挂载，请先 umount"; exit 2
fi
echo "[check] 通过（USB + $MODEL + 1TB + 未挂载）。5 秒后开始，Ctrl-C 取消..."; sleep 5

# ---------- 1. 修 ESP（vfat 超级块，本次事故卡点） ----------
if [ "$FIX_ESP" = "1" ]; then
  echo "[1/5] fsck.vfat ESP 分区 ${DEV}1"
  blkid -o value -s TYPE "${DEV}1" | grep -q vfat || { echo "[FATAL] ${DEV}1 不是 vfat，分区布局异常"; exit 3; }
  fsck.vfat -y "${DEV}1" 2>&1 | tee -a "$LOG" || echo "[warn] fsck.vfat 返回非零，见日志"
fi

# ---------- 2. 恢复封版（母版重启会吃掉标记 L6） ----------
if [ "$SEAL" = "1" ]; then
  echo "[2/5] 恢复封版标记 on ${DEV}3"
  MNT=$(mktemp -d)
  mount -o rw "${DEV}3" "$MNT"
  [ -f "$MNT/usr/local/sbin/firstboot-unique.sh" ] || { echo "[FATAL] firstboot-unique.sh 不在盘上，封版组件缺失"; umount "$MNT"; exit 3; }
  touch "$MNT/etc/.needs-uniq"
  ln -sf /etc/systemd/system/firstboot-unique.service \
         "$MNT/etc/systemd/system/multi-user.target.wants/firstboot-unique.service"
  sync; umount "$MNT"; rmdir "$MNT"
  echo "      标记 + 启用符号链接已恢复"
fi

# ---------- 3. 整盘镜像 ----------
echo "[3/5] dd|pigz → $IMG （953.9G，预计 40~90 分钟）"
echo "IMAGING_START $(date -Is) src=$DEV expect_bytes=$SIZE" >> "$LOG"
set +e
dd if="$DEV" bs=8M status=progress | pigz -1 -p"$(nproc)" > "$IMG"
RC=${PIPESTATUS[0]}/${PIPESTATUS[1]}
set -e
GZ_SIZE=$(stat -c%s "$IMG")
echo "IMAGING_EXIT=$RC gz_size=$GZ_SIZE $(date -Is)" >> "$LOG"
[ "$RC" = "0/0" ] || { echo "[FATAL] 镜像失败 rc=$RC，保留现场见 $LOG"; exit 4; }

# ---------- 4. 校验 ----------
echo "[4/5] 校验：完整解压计字节（约 10~20 分钟）"
BYTES=$(pigz -dc "$IMG" | wc -c)
[ "$BYTES" = "$SIZE" ] || { echo "[FATAL] 字节数不符: $BYTES ≠ $SIZE"; exit 5; }
pigz -dc "$IMG" | head -c 2M > "${IMG}.pt.bin"
fdisk -l "${IMG}.pt.bin" 2>&1 | head -20
SHA=$(sha256sum "$IMG" | awk '{print $1}')

# ---------- 5. manifest ----------
echo "[5/5] manifest"
cat > "${IMG}.manifest.txt" <<EOF
image:        $IMG
source_disk:  $DEV ($MODEL, ${SIZE}B, USB 直读)
created:      $(date -Is)
sha256:       $SHA
bytes_uncompressed: $BYTES  (== source, 校验通过)
sealing:      /etc/.needs-uniq + firstboot-unique enabled = $( [ "$SEAL" = "1" ] && echo "已恢复" || echo "跳过(--no-seal)" )
esp_fix:      $( [ "$FIX_ESP" = "1" ] && echo "fsck.vfat 已执行" || echo "跳过(--no-fix-esp)" )
restore:      sudo bash restore-image.sh $IMG /dev/sdY
EOF
rm -f "${IMG}.pt.bin"
echo "=========================================="
echo "完成: $IMG"
echo "sha256: $SHA"
cat "${IMG}.manifest.txt"
