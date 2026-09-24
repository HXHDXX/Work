#!/bin/bash
# =============================================================================
# a3-hot-read-image.sh —— 路线 A3：纯读热拷贝（工作站上运行，零停机零修改）
# 功能: ssh 到运行中的设备，sync + dd|pigz 拉回整盘镜像（不停任何服务）
# 一致性: 镜像 = "运行中突然断电"状态；克隆机首挂靠 ext4 journal 自愈
# 用法: bash a3-hot-read-image.sh kylin@192.168.1.222
# 教训对应: L4(零修改) L8(接受已知折扣而非赌未知风险)
# =============================================================================
set -euo pipefail
bash -n "$0" || { echo "[FATAL] 脚本自身语法错误，拒绝执行"; exit 9; }
TARGET=${1:?用法: a3-hot-read-image.sh kylin@192.168.1.222}
REMOTE_DEV=${REMOTE_DEV:-/dev/sda}
DEST_DIR=${DEST_DIR:-/Workspace/Work/outputs/golden-images}
SSHOPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30"

mkdir -p "$DEST_DIR"
STAMP=$(date +%Y%m%d-%H%M)
IMG="$DEST_DIR/kylin-v10-arm64-golden-hot-$STAMP.img.gz"
LOG="${IMG}.log"

# ---------- 源盘信息 ----------
SIZE=$(ssh $SSHOPTS "$TARGET" "lsblk -ndbo SIZE $REMOTE_DEV" 2>/dev/null) || { echo "[FATAL] ssh 不通"; exit 2; }
MODEL=$(ssh $SSHOPTS "$TARGET" "lsblk -ndo MODEL $REMOTE_DEV" 2>/dev/null)
echo "[check] 源盘: $TARGET $REMOTE_DEV model=$MODEL size=$SIZE"
[ -n "$SIZE" ] && [ "$SIZE" -gt 0 ] || { echo "[FATAL] 取盘信息失败"; exit 2; }
echo "[note] 选择设备空闲时段运行；成像窗口内避免编译/大写入"

# ---------- 镜像（纯读：sync 后 dd，不停服务不冻结） ----------
echo "[image] ssh 拉取 → $IMG （953.9G 级，数小时；setsid 后台 + IMAGING_EXIT 标记）"
echo "IMAGING_START $(date -Is) src=$TARGET:$REMOTE_DEV expect_bytes=$SIZE" >> "$LOG"
set +e
ssh $SSHOPTS "$TARGET" "sync; dd if=$REMOTE_DEV bs=8M iflag=fullblock status=none | pigz -1 -p6" > "$IMG" 2>> "$LOG"
RC=$?
set -e
GZ_SIZE=$(stat -c%s "$IMG")
echo "IMAGING_EXIT=$RC gz_size=$GZ_SIZE $(date -Is)" >> "$LOG"
[ "$RC" -eq 0 ] || { echo "[FATAL] 拉取失败 rc=$RC"; exit 4; }

# ---------- 校验 ----------
echo "[verify] 完整解压计字节"
BYTES=$(pigz -dc "$IMG" | wc -c)
[ "$BYTES" = "$SIZE" ] || { echo "[FATAL] 字节数不符: $BYTES ≠ $SIZE"; exit 5; }
SHA=$(sha256sum "$IMG" | awk '{print $1}')
cat > "${IMG}.manifest.txt" <<EOF
image: $IMG
source: $TARGET:$REMOTE_DEV ($MODEL, ${SIZE}B, 纯读热拷贝)
created: $(date -Is)
sha256: $SHA
bytes_uncompressed: $BYTES (== source)
consistency: journal 自愈型镜像；克隆机首启建议 e2fsck -f 验证一次
EOF
echo "完成: $IMG"; echo "sha256: $SHA"
