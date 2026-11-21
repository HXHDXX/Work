# 达梦 DM8 + Qt 5.14.2 QDM 驱动 部署文档（飞腾 ARM64 / 麒麟 V10 SP1）

> 适用设备：aarch64（飞腾）、银河麒麟 V10 SP1、离线内网环境
> dm8 介质目录 + 本文档 + `install_dm8_qt.sh` = 完整部署包

## 0. 介质清单与依赖前提

| 文件 | 用途 |
|---|---|
| `dm8_20260312_FTarm_kylin10_sp1_64.iso` | DM8 安装镜像（FTarm 专用，含 DMInstall.bin） |
| `dm8_20260312_FTarm_kylin10_sp1_64.iso_SHA256.txt` | 镜像校验（GBK 编码，脚本会自动提取哈希比对） |
| `dm5D01220176.key` | License 授权文件（有效期至 **2027-06-25**，构建横幅 8.4） |
| `qt_src-3194-20260710.zip` | 达梦官方 Qt QSqlDriver（QDM）源码 |
| `install_dm8_qt.sh` | 一键部署脚本（见第四节） |

**设备前提**（缺一脚本会明确报错/跳过）：

- DM8 阶段：root/sudo、`sha256sum`、`mount -o loop`、`systemd`
- Qt 驱动阶段（可选，缺则跳过并提示）：Qt 5.14.2 SDK 位于 `/opt/Qt5.14.2`，
  且保留模块源码树 `/home/kylin/qt5`（QDM 编译依赖 qtbase 源码里的 `qsqldriverbase.pri`），有 g++/make

## 一、DM8 安装部署过程（实录步骤）

### 1.1 预检

```bash
uname -m            # 必须 aarch64
df -h /             # 磁盘余量 ≥ 10G
sha256sum dm8_*.iso # 与 SHA256 文件比对（txt 为 GBK，取 64 位哈希比对即可）
```

### 1.2 系统准备（root）

```bash
groupadd -f dinstall
id dmdba >/dev/null 2>&1 || useradd -g dinstall -m -s /bin/bash dmdba
grep -q dmdba /etc/security/limits.conf || printf \
"dmdba soft nofile 65536\ndmdba hard nofile 65536\ndmdba soft nproc 65536\ndmdba hard nproc 65536\n" \
>> /etc/security/limits.conf
mkdir -p /opt/dm8 && chown dmdba:dinstall /opt/dm8
```

> ⚠️ **坑 1：安装目录必须为空目录**（新装默认 `/opt/dm8`）。安装器检测目录非空即拒绝安装，且**静默失败仍返回 RC=0**，
> 日志仅一行"安装目录(<实际路径>)下不为空"。不要预创建 `data` 等任何子目录。

### 1.3 提取安装器（安装器/介质不能放 dmdba 无权读取的目录）

```bash
mount -o loop dm8_*.iso /mnt && cp /mnt/DMInstall.bin /home/dmdba/ && umount /mnt
chmod +x /home/dmdba/DMInstall.bin
cp dm5D01220176.key /home/dmdba/
```

> ⚠️ **坑 2**：dmdba 无法进入其他用户家目录（700 权限）读介质。
> 三件套（安装器/key/xml）统一拷到 `/home/dmdba/` 执行。

### 1.4 静默安装配置 auto_install.xml

本构建（2026-03）比官方手册模板**多一个必填节点 `CREATE_DB_SERVICE`**；
dmdba 非 root 只能填 `N`（服务事后用官方 root 脚本注册）：

```xml
<?xml version="1.0"?>
<DATABASE>
<LANGUAGE>ZH</LANGUAGE>
<TIME_ZONE>+08:00</TIME_ZONE>
<KEY>/home/dmdba/dm5D01220176.key</KEY>
<INSTALL_TYPE>0</INSTALL_TYPE>            <!-- 0=全部组件 -->
<INSTALL_PATH>/opt/dm8</INSTALL_PATH>
<INIT_DB>Y</INIT_DB>                       <!-- 随装初始化实例 -->
<CREATE_DB_SERVICE>N</CREATE_DB_SERVICE>   <!-- 非 root 必须 N -->
<DB_PARAMS>
<PATH>/opt/dm8/data</PATH>
<DB_NAME>DAMENG</DB_NAME>
<INSTANCE_NAME>DMSERVER</INSTANCE_NAME>
<PORT_NUM>5236</PORT_NUM>
<PAGE_SIZE>8</PAGE_SIZE>
<CASE_SENSITIVE>Y</CASE_SENSITIVE>
<CHARSET>0</CHARSET>                       <!-- 0=GB18030（默认） 1=UTF-8 -->
<SYSDBA_PWD>PHMadmin1</SYSDBA_PWD>      <!-- 2026-09-16 重建后当前实例口令，可覆盖 -->
<SYSAUDITOR_PWD>Dameng@Audit2026</SYSAUDITOR_PWD>
</DB_PARAMS>
</DATABASE>
```

密码策略：8~48 位，必须同时含**大写+小写+数字**。

> ⚠️ **重要**：`CHARSET` 与 `CASE_SENSITIVE` 是 dminit 时烧死、**建库后不可改**。
> 空库期重建只要几分钟；灌数据定型后只能 DTS 整库迁移。MySQL 迁来的项目常需
> `CASE_SENSITIVE=N`，务必建库前定夺（一键脚本支持环境变量覆盖）。

### 1.5 执行安装（dmdba）

```bash
su - dmdba -c "cd /home/dmdba && ./DMInstall.bin -q /home/dmdba/auto_install.xml"
```

> ⚠️ **坑 3：不要信 INSTALL_RC=0**（各类失败同样返回 0）。
> 真正成功判据：`/opt/dm8/bin/dmserver` 与 `/opt/dm8/data/DAMENG/dm.ini` 同时存在，
> dmdba 日志尾部出现 `[INFO] 安装达梦数据库完成。` 和 `[INFO] 初始化数据库完成。`

### 1.6 root 收尾 + 服务注册 + 启动

```bash
/opt/dm8/script/root/root_installer.sh                    # 注册 DmAPService
/opt/dm8/script/root/dm_service_installer.sh -t dmserver \
      -dm_ini /opt/dm8/data/DAMENG/dm.ini -p DMSERVER      # 注册实例服务
systemctl enable --now DmServiceDMSERVER DmAPService
ss -ltn | grep 5236                                        # 监听验证
```

### 1.7 验证（disql）

```bash
# 密码含 @ 时必须整体加引号，否则连接串解析错乱
/opt/dm8/bin/disql 'SYSDBA/"PHMadmin1"@localhost:5236'
SQL> SELECT INSTANCE_NAME FROM V$INSTANCE;   -- DMSERVER
SQL> SELECT EXPIRED_DATE FROM V$LICENSE;     -- 2027-06-25（key 生效）
```

### 1.8 替换式重建实例（2026-09-16 实录，当前设备即此形态）

（本节 /dm8 为存量设备实录路径；新装设备替换为实际 DM_HOME，如 /opt/dm8）

旧实例无业务数据时，用独立 `dminit` 原地替换（端口仍 5236，参数 GB18030/敏感/8K，密码换为 `PHMadmin1`）：

```bash
# 1) 下线并注销旧实例（卸载脚本等 TTY 确认会悬挂，直接手动清理等价物）
sudo systemctl disable --now DmServiceDMSERVER
sudo kill -9 $(pgrep -f unins[a]taller) 2>/dev/null   # pkill -f 模式会匹配自身命令行，需 [x] 正则防自杀
sudo rm -f /lib/systemd/system/DmServiceDMSERVER.service /etc/init.d/DmServiceDMSERVER \
          /dm8/bin/DmServiceDMSERVER                        # 旧服务包装脚本不删会挡新注册
sudo systemctl daemon-reload && sudo systemctl reset-failed
sudo mv /dm8/data/DAMENG /dm8/data/DAMENG.old-$(date +%Y%m%d)   # 旧数据留档

# 2) 以 dmdba 身份 dminit（注意：会在 PATH 下再追加一层库名子目录！）
sudo mkdir -p /dm8/data/DAMENG && sudo chown dmdba:dinstall /dm8/data/DAMENG
sudo bash -c 'su - dmdba -c "/dm8/bin/dminit PATH=/dm8/data/DAMENG \
  DB_NAME=DAMENG INSTANCE_NAME=DMSERVER PORT_NUM=5236 PAGE_SIZE=8 \
  CHARSET=0 CASE_SENSITIVE=Y \
  SYSDBA_PWD=PHMadmin1 SYSAUDITOR_PWD=Dameng@Audit2026 \
  </dev/null >/home/dmdba/dminit.log 2>&1"'
# 成功判据：日志尾部 “create dm database success.”

# 3) 注册启动（dm_ini 用双层路径）+ 验证
sudo /dm8/script/root/dm_service_installer.sh -t dmserver \
     -dm_ini /dm8/data/DAMENG/DAMENG/dm.ini -p DMSERVER
sudo systemctl enable --now DmServiceDMSERVER
/dm8/bin/disql 'SYSDBA/"PHMadmin1"@localhost:5236'
```

重建后数据目录为 **`/dm8/data/DAMENG/DAMENG`**（dminit 自动追加库名子目录，与随装初始化的
`/dm8/data/DAMENG` 单层布局不同，运维/脚本需兼容两种路径，`install_dm8_qt.sh` 已内置 `find_dm_ini` 兼容）。

> **重装策略（2026-11-20 用户决策）**：重装一律交付全新空库，不恢复业务数据；dexp/dimp 恢复流程废止。

## 二、Qt 5.14.2 QDM 驱动编译部署（实录步骤）

### 2.1 思路

达梦无 Qt 二进制驱动，官方源码包 `qt_src-*.zip` 内含 dm_48/dm_56/dm_57/dm5.12 多套源码，
**Qt 5.14 用 dm5.12 目录**。驱动经 DPI（`libdmdpi.so`）直连数据库，无需 ODBC。
产物 `libqsqldm.so` 放入 Qt 插件目录，Qt 驱动名 **`QDM`**。

### 2.2 依赖

- DPI 头文件：`/opt/dm8/include/DPI*.h`（随 DM8 安装已有）
- DPI 库：`/opt/dm8/drivers/dpi/libdmdpi.so`
- Qt 5.14.2 SDK：`/opt/Qt5.14.2`
- qtbase 源码树：`/home/kylin/qt5/qtbase`（`include(../qsqldriverbase.pri)` 依赖）

### 2.3 编译

```bash
# 解压（无 unzip 时：python3 -m zipfile -e qt_src-*.zip .）
cp -r qt_src/plugins_sqldrivers/dm5.12 \
      /home/kylin/qt5/qtbase/src/plugins/sqldrivers/dm
cd /home/kylin/qt5/qtbase/src/plugins/sqldrivers/dm

# ⚠️ 坑 4：dm.pro 有 3 行硬编码 Windows 路径（C:\dm7_...dmdpi.lib 等），
# 会让链接命令带上垃圾参数，必须先删：
sed -i '/dm7_20210303/d' dm.pro && rm -f dm.pro.user

mkdir build && cd build
/opt/Qt5.14.2/bin/qmake "INCLUDEPATH+=/opt/dm8/include" \
      "LIBPATH+=/opt/dm8/drivers/dpi" "DEFINES+=DM64" ../dm.pro
make -j$(nproc)
```

> ⚠️ **坑 5**：make 的 DESTDIR 是坏路径，产物会被 mv 到根下 `/plugins/sqldrivers/`。
> 构建后 `find` 定位 `libqsqldm.so` 再手工安装。

### 2.4 安装 + 运行时寻址

```bash
cp <产物路径>/libqsqldm.so /opt/Qt5.14.2/plugins/sqldrivers/

# ⚠️ 坑 6：libdmdpi.so 不在系统库路径，Qt 程序加载插件会失败。系统级注册：
printf "/opt/dm8/drivers/dpi\n/opt/dm8/drivers/odbc/dependencies\n" > /etc/ld.so.conf.d/dm8.conf
ldconfig
ldd /opt/Qt5.14.2/plugins/sqldrivers/libqsqldm.so   # libdmdpi.so 可解析、无 not found
```

### 2.5 验证（Qt 端到端）

```cpp
// .pro: QT += sql
QSqlDatabase db = QSqlDatabase::addDatabase("QDM");
db.setHostName("localhost"); db.setPort(5236);
db.setUserName("SYSDBA");    db.setPassword("PHMadmin1");
db.setDatabaseName("DAMENG");
qDebug() << QSqlDatabase::drivers();   // 含 "QDM" 即插件已加载
db.open();                              // 建/插/查中文往返验证
```

## 三、部署完成形态

| 项 | 值 |
|---|---|
| DM8 安装目录 | `/dm8`（dmdba:dinstall） |
| 实例 | 库 DAMENG / 实例 DMSERVER / 端口 **5236**；数据目录 `/dm8/data/DAMENG/DAMENG`（2026-09-16 dminit 重建形态） |
| 数据目录形态 | 新部署一律单层 `/dm8/data/DAMENG`（随装初始化标准形态）；`.20` 设备为双层历史形态（dminit 重建）——应用经 TCP `127.0.0.1:5236` 访问，不受路径差异影响 |
| 服务 | `DmServiceDMSERVER`、`DmAPService`（systemd，开机自启） |
| 管理账号 | SYSDBA / `PHMadmin1`；SYSAUDITOR / `Dameng@Audit2026`（脚本可改） |
| License | `/dm8/bin/dm.key`，**2027-06-25 到期** |
| Qt 插件 | `/opt/Qt5.14.2/plugins/sqldrivers/libqsqldm.so`（驱动名 QDM） |
| DPI 运行库 | `/etc/ld.so.conf.d/dm8.conf` 已注册，全系统可寻址 |

日常运维：

```bash
systemctl restart DmServiceDMSERVER        # 重启数据库
/dm8/bin/disql 'SYSDBA/"PHMadmin1"@192.168.1.222:5236'
```

## 四、一键部署脚本使用说明

```bash
# 在设备上（root）：
sudo bash install_dm8_qt.sh /path/to/dm8目录

# 可选参数（环境变量，均有默认值）：
sudo env SYSDBA_PWD='NewPass123' SYSAUDITOR_PWD='Audit123x' \
     DM_CHARSET=1 DM_CASE_SENSITIVE=N \
     bash install_dm8_qt.sh /path/to/dm8目录

# 大盘数据目录用法（安装目录默认 /opt/dm8，数据目录另置大盘）：
sudo env DM_HOME=/opt/dm8 DATA_PATH=/data/dm8 bash install_dm8_qt.sh
```

脚本特性：

- **幂等可重跑**：DM8 已装（`$DM_HOME/bin/dmserver` 存在，存量 `/dm8` 自动沿用）跳过安装只做服务/连通检查；
  QDM 插件已存在跳过编译。失败修复后直接重跑。
- 全自动：SHA256 校验 → loop 挂载提取安装器 → 用户/限额/空目录 → 静默安装（正确 XML 含
  CREATE_DB_SERVICE=N）→ root 脚本注册服务 → 启动 → disql 验证（含 License 到期日）
  → ldconfig → QDM 编译安装 → **Qt 端到端冒烟**（真实建表/插中文/查询/删表）→ 清理。
- 无 `unzip` 自动回退 `python3 -m zipfile`。
- 每阶段 `[阶段N] [OK]/[FAIL]` 输出，失败即停并给定位提示。
- **完成形态终验**（stage 10）：banner 前对全流程终态只读复核——双服务 active、端口监听、disql 实例、
  dm.key 与介质 md5 比对、License 到期、QDM 驱动 ldd、PHMAPP+dm.ini+phm-app.service、dpkg --audit、
  dmPython 属主真连（设 PYTHON_VENV 时）；任一硬项不满足即 fail。
- 本文所有坑（空目录、CREATE_DB_SERVICE、Windows 残留行、坏 DESTDIR、ldconfig、disql 引号）
  已全部内置规避。

## 五、坑清单速查（人工部署对照）

| # | 坑 | 规避 |
|---|---|---|
| 1 | 安装目录非空 → 静默失败且 RC=0 | 安装目录全空，成功判据看产物文件 |
| 2 | dmdba 读不了其他用户家目录介质 | 三件套拷 `/home/dmdba/` 执行 |
| 3 | 2026 构建要求 `CREATE_DB_SERVICE` 节点 | 非 root 固定 N，服务后注册 |
| 4 | dm.pro 硬编码 Windows 路径 | `sed '/dm7_20210303/d'` 删三行 |
| 5 | make DESTDIR 坏路径 | build 后 find 定位 libqsqldm.so |
| 6 | libdmdpi.so 运行时找不到 | `ld.so.conf.d/dm8.conf` + `ldconfig` |
| 7 | disql 密码含 `@` 解析错乱 | `'SYSDBA/"密码"@host:5236'` 整体引号 |
| 8 | CHARSET/CASE_SENSITIVE 建库后不可改 | 建库前定夺，空库期重建成本最低 |
| 9 | dm_service_uninstaller.sh 卡 TTY 交互，`yes\|` 喂不进 | 按 PID 杀；手动删 unit+包装脚本（见 1.8） |
| 10 | `pkill -9 -f <关键词>` 匹配到自身 ssh 命令行而自杀 | 用 `unins[a]taller` 式正则或按 PID |
| 11 | 旧服务包装脚本 `/dm8/bin/DmService*` 残留挡新注册 | 注册前先删；报“服务脚本文件已存在”即此因 |
| 12 | 独立 dminit 在 PATH 下追加库名子目录 | dm.ini 双层路径兼容（脚本已内置 find_dm_ini） |
| 13 | 冒烟后进程残留已删 cwd，8c/8f 的 pip 报 OSError Errno 2（8c「wheel 不匹配」为误诊文案） | 冒烟清理后 `cd /` 回位（脚本已修，2026-11-16） |
| 14 | 介质清单登记 git 已跟踪文件→每次提交即过期（追刷两次） | 清单只登记未跟踪介质；入库文件由 git 背书（2026-11-16 起摘除两行） |
| 15 | 20260312 构建要求 auto_install.xml 含非空 `SYSSSO_PWD` 节点，缺失报"配置文件SYSSSO_PWD节点字符串不能为空"（判例 2026-11-20，.30 实测；20260324 构建无此要求。两构建可经版本横幅区分：20260312=8.4，20260324=8.1.1） | 脚本已内置默认值 `SYSSSO_PWD=Dameng@Sso2026`（环境变量可覆盖），模板已带该节点 |

> **dmPython 集成（2026-09-16 起）**：`sudo env PYTHON_VENV=/path/to/venv bash install_dm8_qt.sh ...` 自动执行：离线装 `wheels/dmpython-*.whl`（已可导入则跳过）→ 拷 crypto 库修 -70089 → **干净环境连接验证**。未设 PYTHON_VENV 则提示跳过。详见《dmPython连接配置方案.md》。

> **Python3.12+SSL 支撑（2026-09-16 起）**：脚本阶段 8b 自动检测 `/usr/local/bin/python3.12` 的 `import ssl`，失败时：离线安装 `debs/` 里 10 个编译依赖包（libssl-dev/libffi-dev/sqlite 等，已装自动跳过）→ 用包内 `Python-3.12.14.tgz` 重编安装（3.12 系列 ABI 兼容，venv/site-packages 不受影响）→ 验证 `_ssl`。`PY_FIX_SSL=skip` 可禁用。设备已有源码树时也可手工增量 `make`（见《dmPython连接配置方案.md》背景）。

> **8b kit 兜底硬化（2026-11-20）**：8b kit 兜底已逐包化＋防降级闸（判例 2026-11-20 .20 基线失配三连），跨基线部署以 apt 隧道为正道。

> **客户需求对齐（2026-09-16）**：Python 以客户基准 **3.12.2** 编译，命令逐字对齐客户文档（`./configure --enable-optimizations --prefix=/usr/local` + `make -j$(nproc)` + `sudo make altinstall`；PGO 构建约 30~60 分钟）。基础工具 build-essential/gcc/g++/make/curl 设备已有，wget 已入 debs/。**CAN 调试助手经确认不安装；PyCharm 已于 2026-11-13 补装（见下条）**。sqlite3 CLI 已入 debs/（universe 池，3.31.1；目标设备本就已安装）。

> **Python 3.12 设为默认（2026-11-13，设备 kylin@192.168.1.20，sudo 密码 `qwer1234`）**：altinstall 装法不会产生 `python3` 命令，靠 `/usr/local/bin`（PATH 优先于 `/usr/bin`）补两条符号链接即可：
> `sudo ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3 && sudo ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip3`
> 交互 shell 默认 `python3`/`pip3` → 3.12.2；系统 `/usr/bin/python3`（3.8.10）与 `python`（2.7.18）**刻意不动**，防破坏麒麟系统工具。venv（`/home/kylin/venvs/phm`）与 systemd 服务用绝对路径，不受影响。

> **PyCharm + QtCreator + GL 开发链补装（2026-11-13，设备 kylin@192.168.1.20）**：
> - **PyCharm 2025.3**（build 253.28294.336，统一版免费层=社区版功能，aarch64）：联网机下载 `pycharm-2025.3-aarch64.tar.gz`（1.2G，sha256 已随部署包归档于 206/dm8/）→ scp 摆渡 → `sudo tar -xzf -C /opt` → `sudo ln -sfn /opt/pycharm-2025.3 /opt/pycharm` + `sudo ln -sf /opt/pycharm/bin/pycharm.sh /usr/local/bin/pycharm` + 写 `/usr/share/applications/pycharm.desktop`（`Exec=/opt/pycharm/bin/pycharm.sh %f`、`Icon=/opt/pycharm/bin/pycharm.svg`、`StartupWMClass=jetbrains-pycharm`）。自带 aarch64 JBR；要求 glibc≥2.28（设备 2.31 ✓）。验收：`file /opt/pycharm/jbr/bin/java` 为 aarch64 ELF。
> - **QtCreator 4.11.0-3kylin6k0.6** 设备已有（麒麟源 apt 装的 /usr/bin/qtcreator），无需另装；Qt Kit 指向 /opt/Qt5.14.2 即可。
> - **缺库 `cannot find -lGL`**（QtCreator 新建 GUI 工程必撞）：设备只有 GL 运行时（libGL.so.1），缺开发链接件 `libGL.so`（属 `libgl-dev` 包）。正解包 `libgl-dev_1.3.2-1~kylin0.20.04.2_arm64.deb` 已入 `debs/`（麒麟源直链 `http://archive.kylinos.cn/kylin/KYLIN-ALL/pool/main/libg/libglvnd/`，目录列表 403 但文件直链可取，版本须与在位 libglvnd 运行时精确一致）。⚠️ libgl-dev 名义依赖拖 `libglx-dev→libx11-dev` 约 9 包链——离线最小修法：`dpkg-deb -x` 解包后整树拷入 `/usr`（得 `libGL.so` 链接＋GL 头 gl.h/glext.h/KHR＋pkgconfig），绕开 X11 链且不碰 dpkg 账本；将来需 EGL/GLES dev（Qt Quick ES2）再扩链。验收：`echo 'int main(){return 0;}' | g++ -x c++ - -lGL` 链接通过。

> **8d–8g 已脚本化（2026-11-13）**：`install_dm8_qt.sh` 新增四阶段，均幂等（条件已满足即跳过）——8d python3/pip3 默认指向 3.12（`/usr/local/bin` 符号链接，系统 `/usr/bin/python3` 不动）；8e libGL 开发链落位（`debs/libgl-dev_*.deb` 经 `dpkg-deb -x` 整树拷入，不走 `dpkg -i`）；8f venv 四包安装（numpy/pandas/statsmodels/openpyxl 精确 pin，验收 import＋`pip check`）；8g PHM 业务面（建 PHMAPP 账号授 PUBLIC/RESOURCE、写 `/home/kylin/.config/phm/dm.ini`、落位 `phm-app.service` 不 enable）。PHMAPP 密码经环境变量 `PHMAPP_PWD` 覆盖，缺省 `PHMapp2026`（8~48 位含大小写数字）。

> **GFB 基线换血（2026-11-16，.30 设备 kylin@192.168.1.30 全形态部署实录，无 IDE）**：206 车机运行时已统一 GFB 定制基线（V10-GFB-020 源，运行库带 gf0/gf03/gf1.5 后缀），qt-env 包 debs/ 原 26 个 dev 包严格 `=` 依赖失配；且 xargs 分批 dpkg 任一失败会把同批**级联**卡成半配置（.30 实测级联误伤 20+ 含设备预装系统 dev 链，修复=按 dpkg.log upgrade 行取原版回装）。已固化：
> - debs/ 换血 26 包为 GFB 原版（含 qtcreator/qtcreator-data→4.11.0-3kylin**6k0.4gf1.0**；libicu-dev/icu-devtools 用 suite 的 k1 非 gf 版，锚定 .30 在位 libicu66），取自 archive.kylinos.cn V10-GFB-020 直链；换后全套严格 pin 审计 0 失配（唯一残留 libqt5serialport5 5.12.12 自身漂移，无 pin 无害，**勿**换 suite 的非 gf 构建）。
> - dm8/debs 侧 libssl-dev（需 1.1.1f/设备 1.1.1w-gf1.5）、libsqlite3-dev+sqlite3（k0.4/gf0.2）、tk-dev（无 tcl/tk dev 链）在 GFB 设备 dpkg -i 必炸：摆渡时移出，ssl/sqlite 头文件 `dpkg-deb -x` 整树落位（Python _ssl 实测链设备 1.1.1w 正常，tkinter 不可用、11 件套不受影响）；uuid-dev/libffi-dev/zlib1g-dev 已装则脚本幂等跳过。
> - **装前必校时**：.30 出厂时钟停 2000-01-01（RTC 同错，疑 CMOS 电池空电），license 校验必失败；`sudo date -s` 后 `hwclock --systohc`，重启复查。
> - **无 IDE 形态**：kit 目录不放 `debs/`（脚本 stage 1 自动跳过）→ deb 另行过滤 qtcreator/qtcreator-data/qbs-common/libqbscore 四包后 `dpkg -i`；PyCharm 不摆渡即不装。.30 验收全绿：双服务 active+5236、disql、Qt↔DM 中文冒烟、dmPython 干净环境连接（PHMAPP 业务账号真实连库）、11 件套 import+pip check、python3→3.12.2、dpkg audit 0。

> **GFB 换血补遗（2026-11-16 二次）**：dm8/debs 三个失配包已替换为源内 GFB 原版——libssl-dev 1.1.1w-0+deb11u1gf1.5、libsqlite3-dev/sqlite3 3.31.1-4kylin0.6k0.1gf0.2（与 .30 在位运行时精确一致），tk-dev 已从 kit 删除（源内无可装变体，tkinter 非必需；将来需要 tkinter 时从麒麟源直链取 tk-dev 8.6.9+1 并同装 tcl/tk dev 链）。上一条「摆渡时移出＋头文件 dpkg-deb -x 落位」程序就此作废——kit 在 GFB 设备可直接 dpkg -i，零手工适配；SHA256SUMS.txt 已同步。注意：旧基线（非 gf）设备勿用这三个新包。

> **重灌复部署实录＋kit 定稿（2026-11-16 晚，.30 重装同版 GFB 系统后全流程复跑）**：零手工适配流程验证成立——qt-env 26＋dm8 3 个 GFB 换血包直接 dpkg 全绿。唯 6 个 dev 包二次失配（libexpat1-dev 需 0.8build1、libxcb-shm0/randr0/xinerama0/xkb/sync-dev 需 gf0.1），已按设备运行时锚定换入 kit（qt-env debs 累计 32 个 GFB 版）。教训：**pin 审计必须锚目标设备 dpkg-query 实况，源索引仅参考**——源内 runtime 版本集与设备在位版本存在 build1/gf 双轨偏差。
> - **脚本确定性坑（两台设备复现）**：阶段 8c/8f 的 `sudo -n -u <owner> pip install` 在脚本上下文必失败（8c 报「wheel 版本/架构不匹配」属误诊、8f 报 OSError Errno 2），同命令交互手工执行即成功。标准处置＝手工 `pip install --no-index` 装 dmpython wheel / 11 件套后重跑脚本过幂等闸（8c 走「已可导入」路径、8f 走 freeze 全字匹配跳过）。**根因已修**：冒烟目录 rm 后进程残留已删 cwd，pip 的 os.getcwd() ENOENT——脚本已在冒烟清理后加 `cd /`（2026-11-16，A/B 复现实证：已删 cwd 必现 Errno 2、cd / 后同命令即成功）。
> - 重装系统后时钟必回 2000-01-01（CMOS 电池空电），装前校时＋`hwclock --systohc` 为固定动作。
> - IDE 排除形态复验通过（qtcreator/qtcreator-data/qbs-common/libqbscore 四包与 PyCharm 双 absent）。
> - **IDE 临时补装（2026-11-18，.30 按用户要求恢复 IDE 形态；按需操作，镜像默认不装 IDE）**：qt-env debs 四包（qtcreator/qtcreator-data 4.11.0-3kylin6k0.4gf1.0＋qbs-common/libqbscore 1.13.1-2build1）单次 `dpkg -i` 全绿零依赖缺口；PyCharm 2025.3 按 §五补装程序摆渡落位（sha256 复核一致），libGL.so 开发链接件设备本就在位无需补。验收：dpkg --audit 0、JBR aarch64 ELF。

> **ftg340 GPU 硬件渲染接线（2026-11-18，.30 定稿并经重启验证）**：206 车机（飞腾D3000M/麒麟V10）ftg340 厂商用户态（EGL/GL/GAL 栈）装在私有目录 /usr/lib/aarch64-linux-gnu/d3000m/ 且默认不在链接器搜索路径 → 所有 EGL 应用（含 hx-native-app xcb_egl）静默走 Mesa 软渲染。修法已入 stage 8h（幂等）：写 /etc/ld.so.conf.d/00-ftg340-d3000m.conf（内容＝厂商目录一行）+ ldconfig；00- 前缀保证排序在 aarch64-linux-gnu.conf 之前，撞名 libEGL/libGL/libgbm/libGLESv2 时厂商栈胜出。安全性：厂商栈 NEEDED 的是字面 libdrm.so.2.4.0（仅存于私有目录），与系统 libdrm.so.2 零撞名；内核驱动（galcore，/dev/ftg340）设备树自动加载，三层开机自恢复，无需启动脚本。回滚＝删 conf＋ldconfig。

> **Web 七件扩充（2026-11-13，.20 设备已装验讫）**：stage 8f pin 扩至 11 件——fastapi==0.162.5 / uvicorn[standard]==0.54.0 / python-can==4.6.1 / websockets==17.4 / pydantic==2.14.3 / apscheduler==3.11.3 / python-multipart==0.0.33；wheelhouse-cust/ 现 42 wheel（四包闭包 15＋Web 闭包 27，均 aarch64 cp312 精确 pin 制备）。⚠️ Web 链约束 wrapt<2：安装时 wrapt 2.5.2→1.17.3 降级，statsmodels/numpy/pandas/openpyxl 复验 import 绿＋pip check 无告警。设备验收：七件 import OK（fastapi 0.162.5 / uvicorn 0.54.0 / pydantic 2.14.3）。

## 六、真机 E2E 验证记录（2026-09-16）

部署包已在目标设备（kylin@192.168.1.222）全脚本实跑通过，逐阶段结果：DM8 幂等跳过→disql/LICENSE→DPI 注册→QDM→**Qt↔DM 中文冒烟通过**→dmPython 干净环境连接通过→Python _ssl 验证→清理，全绿。原始日志见 `验证记录/`。重启后复查：达梦双服务 active+5236 监听+disql OPEN+python _ssl 正常，均开机自启级稳定。修复记录：PY_FIX_SSL 变量缺省值 bug（set -u 下崩溃）已修。

## 七、客户新增 Python 依赖（numpy / pandas / statsmodels / openpyxl）

客户在目标设备的 Python 3.12 环境新增四个依赖：**numpy、pandas、statsmodels、openpyxl**。
目标环境与部署包主体相同：**aarch64（飞腾）/ 麒麟 V10 SP1 / 离线内网**，无公网 pip 源，只能 wheelhouse 摆渡。

### 7.1 现状边界（先读）

- `install_dm8_qt.sh` 阶段 8f 已**自动化安装这四个依赖**（精确 pin：numpy==2.5.4 / pandas==3.1.1 / statsmodels==0.15.0 / openpyxl==3.1.5，与 dmPython 阶段同门：需 `PYTHON_VENV`）。
- 15 个 wheel（4 顶层＋11 传递依赖）已随部署包提供：`wheels/wheelhouse-cust/`（2026-11-13 按 .20 设备 `pip freeze` 精确 pin 制备）。
- 本节 7.2/7.3 流程保留作 wheelhouse 人工补制备参考；7.4 的验收已内置进脚本阶段 8f。

### 7.2 联网机准备 wheelhouse

优先用**同架构（aarch64 Linux）联网机**直接下载，最稳妥：

```bash
mkdir -p wheelhouse-cust
python3.12 -m pip download numpy pandas statsmodels openpyxl \
  -d wheelhouse-cust --only-binary=:all:
```

只有 x86_64 联网机时，必须显式交叉指定目标平台与解释器，否则下到 x86 wheel、目标设备装不上：

```bash
python3.12 -m pip download numpy pandas statsmodels openpyxl \
  -d wheelhouse-cust \
  --platform manylinux2014_aarch64 \
  --platform manylinux_2_17_aarch64 \
  --platform manylinux_2_28_aarch64 \
  --python-version 312 \
  --implementation cp \
  --abi cp312 \
  --only-binary=:all:
```

> ⚠️ **传递依赖警告**：statsmodels→scipy、patsy；pandas→python-dateutil、pytz、tzdata；openpyxl→et-xmlfile；
> 各包还会共用 packaging 等。**以联网机 pip 实际解析下载的清单为准，不能只拷 4 个顶层 wheel**——
> 建议 `wheelhouse-cust/` 整目录原样摆渡。

### 7.3 目标设备离线安装

在目标设备的部署用 venv 内（即 `install_dm8_qt.sh` 的 `PYTHON_VENV` 指向、装有 dmPython 的那个 venv）：

```bash
source /path/to/venv/bin/activate
pip install --no-index --find-links /path/to/wheelhouse-cust \
  numpy pandas statsmodels openpyxl
```

### 7.4 验收

```bash
pip check   # 成功输出 "No broken requirements found."
python -c "import numpy, pandas, statsmodels, openpyxl; \
  print(numpy.__version__, pandas.__version__, statsmodels.__version__, openpyxl.__version__)"
```

四包版本正常打印且 `pip check` 无告警，即安装完成。

## 坑位补录：2503-update1 镜像基线漂移（2026-11-19 .30 重灌实录）

| 坑 | 症状 | 修法（已固化进脚本） |
|---|---|---|
| KySec 默认 enabled | kit 脚本 RC=126「KYSEC: 权限不够」 | 完全关闭两层：setstatus disable（内核运行态）＋ security-switch --set custom（正确调用须带空模块列表：security-switch --set custom --list ""；裸 --set custom 报参数错误且不生效、重启即复活——2026-11-20 .30 重启实测 custom+空列表持久 disabled）时序：KySec 拦的就是 kit 脚本执行本身，脚本 stage0 自关闭跑不到——须先 ssh 内联系统命令（sudo setstatus disable && sudo security-switch --set custom --list ""）关闭，再跑任何 kit 脚本（含 apt-tunnel.sh；2026-11-19 .30 重灌实录）。 |
| 新镜像不带 g++ | 冒烟/QDM 编译失败；kylin g++-9 不注册 alternatives | 预检 fail-fast；仅有 g++-9 时自动补软链 |
| /data 只读位 555 | 静默安装报「PATH节点文件路径没有写权限」 | 阶段2 预建 $DATA_PATH 并 chown dmdba |
| 基线漂移 gf0.2→gf0.4 | kit dev 包严格依赖失配，dpkg -i 留 iU 半配置 | pkgs_ensure：apt 优先（隧道）+ kit 兜底 + iU 残留即 fail |
| venv 未预建 | 8c 预检 fail | 8c 以 python3.12 代建 venv |

> **.30 设备 vddaemon 电源管理策略会定时重启**（2026-11-20）：长任务（安装/导入/镜像）前先 `systemctl stop vddaemon vddaemon.timer`。

**apt 判例两则（2026-11-19）**：① `apt --fix-broken install` 必须不带包名——带名会让 iU 包诱导 apt 降级运行库（错误解）；② fix-broken 可能把失配包直接**移除**（当天移了 libgl-dev 全家）——修复后必须对账目标包集合并补装。

**apt 隧道**：现场借道能上网的工作本机：`ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>`，设备侧 `sudo bash apt-tunnel.sh on`。

## GPU 驱动栈定型记录（2026-11-20 .30 全谱实测）

**定型配置（172×us1.1.10-kylin43）**，重复安装按此表：

| 件 | 版本 | 指纹（srcversion） | 来源 |
|---|---|---|---|
| 内核 | linux-image-5.4.18-172-generic 5.4.18-172.166 | — | deb 已入 kit `debs/`（三件套 sha256 见文件）；重下直链 `http://archive.kylinos.cn/kylin/KYLIN-ALL/pool/main/l/linux/`（172.166 未入 apt 索引，仅直链可装） |
| GPU ko | ftg340 **1.1.7**（随内核包） | B41991B541BA938DD36A5E2 | linux-modules-extra-5.4.18-172-generic 5.4.18-172.166 |
| GPU us | ftg340 **1.1.10-kylin43** | — | deb 已入 kit `debs/`（sha256 97a683de…46285b6）；重下 URL：`http://archive.kylinos.cn/kylin/KYLIN-ALL/pool/main/f/ftg340/ftg340_1.1.10-kylin43_arm64.deb` |
| CAN | mcp251x（随内核包） | D7B56D5E57E118F9CE0A592 | 同内核包（159 以下内核的 mcp251x 是旧源，CAN 不可用——"169 以上才能访问 CAN"） |

**安装与验证**：`sudo dpkg -i ftg340_1.1.10-kylin43_arm64.deb` → 重启 → 验证：`uname -r`＝172、`dpkg -l ftg340`＝1.1.10-kylin43、`modinfo ftg340|grep -E version\|srcversion`＝1.1.7/B41991…、`glmark2-es2` GL_VERSION＝V1.1.10、`ip link` 有 can0/can1。

**回滚路径**：①回 us1.1.5：设备 `/home/kylin/us-backup-115/ftg340-files-1.1.5-kylin33.tgz`（6.6GB 全量文件包，源里已无此版）——⚠️×ko1.1.7＝致命楔死组合，仅取证用；②升 us1.3.0：apt 直接有（但重放压力下有 GPU hang，劣于 1.1.10）。

**配套规律（当日 5 格实测）**：ko×us 必须同代——155 栈（ko1.1.2×us1.1.5）与 87 栈（ko1.1.5×us1.1.7-kylin38）全正常；ko1.1.7×us1.1.5＝GPU hang 多发＋假恢复楔死（整机硬死）；×us1.3.0＝hang 仍在但恢复真实；×us1.1.10＝零 hang＋恢复真实＋**地图图层同步闪烁**（待飞腾答复，工单诉求 1.1.7-kylin38/39 或闪烁修复版）。飞腾 PhyFusion 手册自证："麒麟V10 2503（内核5.4+）配套 FTG340 驱动 1.1.10+"。

**证据包**：`~/Documents/gpu-hang-20261120.tar.gz`（厂商报告）＋`gpu-hang-replay-kit.tar.gz`（复现套件）＋`gpu-hang-internal-appendix.md`（内部存档）；ftg340 全版本谱系见包内 changelog（1.1.7-kylin34/37/38/39 公开池已 404，仅工单可得）。

> **补遗（2026-11-20 晚）**：172 内核三件套（image 17.8M／modules 12.6M／modules-extra 46.4M）已入 kit `debs/` 并镜像至设备 `/home/kylin/kitsave/`（连同 ftg340 1.3.0）；`ftg340_1.1.10` 件在设备 `/home/kylin/`。新机复装顺序：dpkg 三件套内核 → dpkg ftg340 1.1.10 → 重启 → 五条验证。⚠️172.166 不在 apt 索引内（apt-cache madison 查无），只能直链/kit 安装。

> **补遗二（2026-11-20）**：原始升级包 `~/Downloads/5.4.18-172.166_arm64.tar.gz`（实为未压缩 tar）五件 deb 已全部入 kit：三件套 sha256 与池直链件**逐字节一致**（链路验证闭环），headers 两件（all 11.7M＋generic 1.3M）一并补入——若日后需在 172 上编任何核外模块（DKMS 类），headers 必备。新机复装按需五件或最小三件＋us。

## 车机电源策略定型（2026-11-20，高性能不休眠，五层）

**背景事故链**：两次"卡死"（15:54/16:38）验尸同签名——journal 尾部 `kylin-process-manager: subCondition : idle_low_Load enter → suspendEffectEffects` → `kernel: ata1: SATA link down`（ata1＝系统盘 sda！）——模拟导航无人键鼠输入被判 idle，kpm 节能把**系统盘 SATA 链路**掐断，全系统 IO 冻死。与 GPU/驱动无关（两 boot 内核零 GPU hang）。

| 层 | 配置 | 持久化 |
|---|---|---|
| 1. kylin-process-manager 拆除 | `systemctl disable --now kylin-process-manager-daemon.service`＋`systemctl mask` 同单元（真身 `/usr/bin/kylin-process-manager-daemon`；autostart → `.disabled` 保留为辅） | systemd disable+mask（重启不复活，2026-11-20 注记） |
| 2. systemd 睡眠 | `systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target` | mask（11-19 已做，复核在位） |
| 3. CPU 调频 | 8 核 `scaling_governor=performance` | `car-machine-perf.service`（kit 有副本，enable 自启） |
| 4. SATA 链路电源 | `link_power_management_policy=max_performance`（**默认竟是 min_power——链路断开的帮凶**） | 同 service |
| 5. UKUI 会话 | `sleep-display-ac=0`、屏保 idle 关；11-19 的 dconf 策略锁层（ag-4137bd）防回写、任务栏 hidepanel=true（判例 2026-11-21，面板自持设置无回写风险，不入 dconf 锁） | gsettings＋dconf 锁 |

**service 安装**：`sudo cp car-machine-perf.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now car-machine-perf.service`

**验证**：`systemctl is-enabled car-machine-perf`（enabled）｜`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`（performance）｜`cat /sys/class/scsi_host/host*/link_power_management_policy`（max_performance）｜`systemctl list-unit-files | grep -E 'sleep|suspend' `（masked）｜`pgrep -f kylin-process-manager`（空）｜`gsettings get org.ukui.screensaver idle-activation-enabled`（false）｜`gsettings get org.ukui.power-manager sleep-display-ac`（0）｜`gsettings get org.ukui.panel.settings hidepanel`（true）。

**判例注记（2026-11-20 .20 实机）**：kpm 拆除正解＝`systemctl disable --now kylin-process-manager-daemon.service`＋`systemctl mask`——真身 `/usr/bin/kylin-process-manager-daemon`；杀进程/禁桌面 autostart/`chmod -x` 均无效（kpm 由该 systemd 单元复活）。
**perf 单元硬化**：等 sysfs 就绪（30×2s 轮询）＋写后回读断言——oneshot 在 `After=multi-user.target` 即写 cpufreq/SATA sysfs 会【假绿】（sysfs 晚绑定，bash 无 set -e 静默吞写失败，重启后回落 schedutil/min_power）。

## 八、整机一键总装（provision_206.sh）

> 2026-11-20 新增：把 KySec/时钟/g++ 预检、五层电源防护、内核/GPU 定型栈、双 kit 部署、PyCharm 串成分阶段幂等的总装入口。各阶段判例出处见本文对应各节。

```bash
# 前置（KySec enabled 时它拦的就是脚本执行，必须先在 ssh 会话内联执行，勿放进脚本）:
sudo setstatus disable && sudo security-switch --set custom --list ""
# 设备上（root）:
sudo bash provision_206.sh             # 无参=从 P0 自动推进到断点（FAIL 或待重启）
sudo bash provision_206.sh P5          # 只跑指定阶段（P0~P6）
sudo bash provision_206.sh --reboot    # P2 装完内核直接重启（缺省停在提示）
```

- 阶段：P0 预检（KySec/时钟/g++）→ P1 五层电源防护 → P2 内核 172.166＋ftg340 1.1.10 → P3 五条验证 → P4 双 kit（`../qt5.14.2-env-deploy/install_qt_env.sh` ＋本目录 `install_dm8_qt.sh`）→ P5 PyCharm（tarball 未摆渡即跳过）→ P6 总验。
- 断点/重启续跑：全阶段幂等（已满足即 [OK] 跳过），fail 即停；P2 换内核或 GPU 驱动后须重启一次，重启后无参重跑自动从 P3 续。
- g++ 缺失时自动借 apt 隧道安装；隧道未开则提示两步——工作站侧 `ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>`（保持会话），设备侧 `sudo bash apt-tunnel.sh on`，再重跑。
- `PYTHON_VENV` 缺省 `/home/kylin/venvs/phm`；`SYSDBA_PWD`/`PHMAPP_PWD` 等环境变量原样透传（缺省同两 kit 头注）。
- 音量定型已含：P1 末以会话用户 `amixer -D pulse sset Master 100% unmute` 定最大音量（kylin 构建 pactl 无 set-sink-volume 子命令），P6 复核 `[100%]` `[on]`。
- P6 总验在最终重启后进行：P5 末落 `/var/lib/provision-206.stamp` 戳记，P6 以 `/proc/uptime` 换算 boot 纪元、须晚于戳记方放行（重启门）；全量断言全绿才打印 `PROVISION-ALL-GREEN`。

> **渲染模式定案（2026-11-20 晚复验）**：**默认 ST**（探针自然通过，GBM 反向流）——kpm 拆除＋五层策略后，显式 ST 与默认 ST 两轮（含跨重启）复验零闪，**无需设置 HX_MAP_RENDER_BACKEND**。勘误：此前"ST×us1.1.10 同步闪"归因有误，真凶为 kylin-process-manager 设备节能动作对 DMA-BUF/fence 同步路径的干扰；us1.1.10 无闪缺陷（WC 当时的"不闪"只是绕开了被干扰的路径）。
