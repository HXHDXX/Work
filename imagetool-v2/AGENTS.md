# imagetool-v2/AGENTS.md

> 整机镜像工具集：车机盘 → 金镜像，零修改路线。操作手册详细：`./README.md`

### 入口
- `a1-usb-disk-image.sh` 拆盘直读（首选）：`sudo bash a1-usb-disk-image.sh /dev/sdX`
- `a2-live-usb-image.sh` Live U 盘冷读 + ssh 推送
- `a3-hot-read-image.sh` 运行中设备纯读热拷贝：`bash a3-hot-read-image.sh kylin@IP`
- `restore-image.sh` 金镜像写回：`sudo bash restore-image.sh golden-*.img.gz /dev/sdX`

### 安全红线
- 一律 `sudo bash` 运行；脚本内置 `bash -n` 自检（语法错 exit 9）
- restore 仅写可移动盘；写固定盘须 `FORCE_TARGET=1` 显式解锁
- EXPECT_MODEL/EXPECT_SIZE 不匹配即拒绝；pigz 缺失即拒绝执行
- 管道逐段校验 PIPESTATUS；manifest 必含 bytes_uncompressed（禁 gzip 估算）

### 约定
- IMAGING_START/EXIT 标记文件：setsid 后台发射 + 轮询标记确认退出
- L1/L4/L6 编号教训注释对应历史事故，改脚本前先读勿删
- 校验即测试：`pigz -dc *.img.gz | wc -c` 对比 expect_bytes；`sha256sum` 对 manifest
