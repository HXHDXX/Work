# 192.168.1.20 达梦数据库备份与恢复手册

> 备份日期：2026-11-16 ｜ 设备：kylin@192.168.1.20（银河麒麟 aarch64）｜ 数据库：达梦 DM8，实例 DMSERVER，安装根 /dm8，数据目录 /dm8/data/DAMENG（11G，多为预分配文件）

## 备份件

| 位置 | 文件 | 大小 | md5 |
|---|---|---|---|
| 本机 | 206/dm-backups/192.168.1.20/dm_full_20261116.dmp（gitignored） | 2.0G | 556b54d5b65450931250ce8f7db91f67 |
| 目标机 | /home/kylin/dm-backup/dm_full_20261116.dmp | 2.0G | 同上（scp 后已对验） |

覆盖范围：全库逻辑导出（FULL=Y）＝ SYSDBA + PHMAPP + PHM 三模式；PHM 业务数据 34 表（含视图 1、序列 1、权限）。系统模式（SYS/SYSAUDITOR/SYSSSO/CTISYS）由安装程序重建，不在 dump 内。

## 备份命令（目标机上）

    /dm8/bin/dexp USERID=SYSDBA/<密码>@127.0.0.1:5236 \
      FILE=dm_full_20261116.dmp LOG=dexp_full_20261116.log \
      DIRECTORY=/home/kylin/dm-backup FULL=Y PARALLEL=1 TABLE_PARALLEL=1

密码见目标机 /home/kylin/bushu/backend-bushu/config.py 的 DM_PASSWORD 默认值。

## ⚠ 关键坑：dexp 默认并行会静默丢行

默认 PARALLEL=16, TABLE_PARALLEL=8。本机并行连接被拒（日志出现 -70019 网络通讯失败 / -70028 创建SOCKET连接失败 警告）时，dexp 不报错、表级照常显示「导出结束」，仅导出部分行：首跑 CHASSIS_HISTORY 只导出 20.9万/167.7万 行（丢 87%），dump 仅 472M 且总结论仍是「成功终止导出」。必须 PARALLEL=1 TABLE_PARALLEL=1 重导（2.0G，无警告），并逐表对账。

对账方法：日志行「表PHM.<T>导出结束，共导出 N 行数据」与 select count(*) 全表比对（本次 34/34 一致，另经 CREATED_AT 时间戳切分证实差异非增量写入）。

## 恢复步骤（dimp）

前提：目标机已装同版本 DM8 且实例运行中。

    /dm8/bin/dimp USERID=SYSDBA/<密码>@127.0.0.1:5236 \
      FILE=dm_full_20261116.dmp LOG=dimp_full.log \
      DIRECTORY=<dump所在目录> FULL=Y PARALLEL=1 TABLE_PARALLEL=1

> ⚠ dimp 同 dexp 必须单线程：FTarm 许可 MAX_SESSIONS=5，默认并行连接被拒后降只读继续跑——46 次「仅可只读」警告、34 表仅 6 表完整仍报「成功终止」(RC=2)；重导前须 DROP 全部残表/视图/序列，残存序列以 ALTER SEQUENCE ... START WITH max(ID)+1 复位防撞号（2026-11-19 .30 实录；经验 20261119-211729-6a9c）。

恢复后核验：select count(*) from PHM.CRANE_UPPER_HISTORY; 应为 733090（其余基准行数见同目录 dexp_full_20261116.log）。

---

# 全机重装还原链（2026-11-16 补全）

设备将重装，本地留存清单（`206/dm-backups/192.168.1.20/` ＋ `Work/206/dm8/`）已构成完整还原链：

| # | 还原什么 | 本地留存 | 位置 |
|---|---|---|---|
| 1 | DM8 安装介质（原装，2026-11-11 就是用它装的本实例） | dm8_20260324_FTarm_kylin10_sp1_64.iso ＋ SHA256 | Work/206/dm8/ |
| 2 | DM8 license | dmE301208192.key | Work/206/dm8/ |
| 3 | 一键安装（装库→建实例→服务→验证，含 8 坑位实录） | install_dm8_qt.sh ＋ INSTALL.md | Work/206/dm8/ |
| 4 | 实例初始化参数（dminit 必须同参，否则 dimp 兼容性风险） | dminit_DAMENG_20261111122147.log | 本目录 |
| 5 | 数据库数据（34/34 表对账过） | dm_full_20261116.dmp | 本目录 |
| 6 | 应用代码＋配置（设备上无 git，此为唯一副本） | bushu_app_20261116.tar.gz | 本目录 |

服务器精确版本（dimp 前提）：`DM Database Server 64 V8 02134284488-20260212-314192-20200`。
dminit 关键参数：page_size=8192, extent_size=16, 大小写敏感=1, charset=0(GB18030), 时区+08:00, 实例名 DAMENG, db 路径 /dm8/data/DAMENG。

## 重装还原步骤

1. 装 DM8：`Work/206/dm8/install_dm8_qt.sh`（或按 INSTALL.md 手动），注册 DmServiceDMSERVER/DmAPService 服务
2. 建实例：按 dminit 参数（上表 #4），实例名 DAMENG
3. 导数据：dimp FULL=Y（命令见上节），密码装库时自定（dump 不含登录口令）
4. 建应用用户口令：PHMAPP 口令需与 config.py 的 DM_PASSWORD 对齐（dimp 建用户但口令不随 dump 走）
5. 还原应用：`tar xzf bushu_app_20261116.tar.gz -C /home/kylin/`，重建/复用 myvenv（包源 Work/206/dm8/wheels）
6. 核验：PHM.CRANE_UPPER_HISTORY=733090 等逐表对账（dexp_full_20261116.log 为基准）

## 未覆盖（重装即失，确认不需要）

- dump 是 2026-11-16 15:27 快照；之后若有新数据，重装前再跑一次 dexp（单线程参数）
- /home/kylin 下 hx-native-app（另有 gitea 远端）、qt5 自编译环境、206-deploy、DSDT、project 等未随本链备份

---

# 恢复实录：192.168.1.30 演练（2026-11-18）

| 项 | 结果 |
|---|---|
| 目标 | kylin@192.168.1.30（重装后新机，DM8 同版本 02134284488-20260212，dminit 参数与源机一致：page8192/GB18030/大小写敏感） |
| 导入 | `/dm8/bin/dimp ... FULL=Y PARALLEL=1 TABLE_PARALLEL=1`，533s，成功终止、1 个警告（PHMAPP 已存在，安装脚本预建，良性） |
| 校验 | 34/34 表行数与 dexp 基线逐一比对零差异；视图 1、序列 SEQ_EQUIPMENT_FAULT_ID 均在位 |
| 完整性 | dump 传输前后 md5 双向对验（556b54d5…1f67） |

注：1.30 系统时钟停在 2000-01-01（重装未对时），跨机看门狗不可用本地钟减远端 mtime（见经验 20261118）；PHMAPP 口令沿用 206 脚本默认，应用默认连 SYSDBA/PHMadmin1，无需改配。

---

# 恢复实录②：192.168.1.30 全新环境重建（2026-11-18 晚）

背景：1.30 当日再次重镜像（新分区方案 /data 735G），206 环境与库全失，按新布局完整重建。

| 项 | 结果 |
|---|---|
| DM8 新装 | **新脚本首战**：DM_HOME=/opt/dm8、DATA_PATH=/data/dm8（大盘落位），幂等链路 RC=0，License 2027-06-25 |
| 数据还原 | dimp 656s 单线程，34/34 表零差异，视图/序列在位，dump md5 三跳对验（本地→/data/206→库） |
| 206 环境 | Qt5.14.2(qmake+fcitx+源码树)、python3.12+SSL(PGO)、venv(dmPython+11 pins)、QDM、GL链、PHMAPP+phm-app.service |
| IDE | qtcreator 4.11.0（89-deb 套件，Kit 预注册）＋ pycharm-2025.3（/opt，sha256 过，pycharm 软链） |

## 新坑：install_dm8_qt.sh 阶段时序（8b 先于 8c）

备份恢复来的 venv `bin/python` 是指向 /usr/local/bin/python3.12 的软链——8b 执行时 8c 还没装 python3.12，悬空软链过不了 `-x` 检查，dmPython/依赖链整段静默跳过（脚本仍 RC=0）。**修法：python3.12 就位后幂等重跑一遍脚本即自愈**。根治（8c 提前或 8b 失败不静默）留给下轮 206 改动。
