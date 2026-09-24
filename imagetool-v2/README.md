# imagetool-v2 —— 零修改整机镜像工具集

> 依据《整机镜像方案修订-教训与零修改路线-20260924.md》落地的脚本化工具。
> 所有脚本内置：`bash -n` 自检（教训 L1）、`set -euo pipefail`、写盘级操作前安全核验、IMAGING_EXIT 完成标记。

## 路线选择

| 脚本 | 路线 | 在哪跑 | 前提 | 一致性 |
|---|---|---|---|---|
| `a1-usb-disk-image.sh` | A1 拆盘直读（**首选**） | 工作站 | SSD 已拔下经 USB 盒接入 | 无损（静止盘） |
| `a2-live-usb-image.sh` | A2 Live U 盘冷读 | 车机 Live 环境 | arm64 Live U 盘启动 | 无损（冷盘） |
| `a3-hot-read-image.sh` | A3 纯读热拷贝 | 工作站 | 设备正常运行 + ssh 可达 | journal 自愈折扣 |
| `restore-image.sh` | 写回/克隆 | 工作站 | 金镜像 + manifest | — |

## 典型用法

```bash
# A1：盘已接工作站（先 lsblk 确认设备名，脚本还会三重核验 USB/型号/容量）
sudo bash a1-usb-disk-image.sh /dev/sdb
#   内置：fsck.vfat 修 ESP + 恢复封版标记(L6) + dd|pigz + 字节数/分区表/sha256 校验 + manifest
#   跳过修ESP/封版: --no-fix-esp / --no-seal

# A2：Live 环境里推到工作站
sudo bash a2-live-usb-image.sh guangbin@<工作站IP>:/Workspace/Work/outputs/golden-images

# A3：不停机拉取（选空闲时段）
bash a3-hot-read-image.sh kylin@192.168.1.222

# 克隆写回（只允许写可移动盘，防误写本机盘）
sudo bash restore-image.sh kylin-v10-arm64-golden-XXXX.img.gz /dev/sdb
```

## 验收清单（脚本已内置，手动复核用）
1. 解压字节数 == 源盘 `blockdev --getsize64`（本批设备 = 1024209543168）
2. 首 2MB 分区表 `fdisk -l` 六分区齐全
3. `sha256sum` 归档
4. 首台克隆机首启后：machine-id / SSH 主机密钥 / 主机名已变化（firstboot-unique 生效）

## 禁用清单（教训固化）
- ✗ 远程 fsfreeze 生产机根分区（L1/L2）
- ✗ 为成像停服务/ remount 的 SSH 静默方案（L4）
- ✗ 未经 `bash -n` + 存活验证的看门狗/后台脚本（L1）
- ✗ `2>/dev/null` 盲目探测（L5）——用 ping + TCP banner
