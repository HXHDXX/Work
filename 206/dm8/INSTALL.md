# 达梦 DM8 + Qt 5.14.2 QDM 驱动 部署文档（飞腾 ARM64 / 麒麟 V10 SP1）

> 适用设备：aarch64（飞腾）、银河麒麟 V10 SP1、离线内网环境
> dm8 介质目录 + 本文档 + `install_dm8_qt.sh` = 完整部署包

## 0. 介质清单与依赖前提

| 文件 | 用途 |
|---|---|
| `dm8_20260324_FTarm_kylin10_sp1_64.iso` | DM8 安装镜像（FTarm 专用，含 DMInstall.bin） |
| `dm8_20260324_FTarm_kylin10_sp1_64.iso_SHA256.txt` | 镜像校验（GBK 编码，脚本会自动提取哈希比对） |
| `dmE301208192.key` | License 授权文件（有效期至 **2027-06-25**） |
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
mkdir -p /dm8 && chown dmdba:dinstall /dm8
```

> ⚠️ **坑 1：`/dm8` 必须为空目录**。安装器检测目录非空即拒绝安装，且**静默失败仍返回 RC=0**，
> 日志仅一行"安装目录(/dm8)下不为空"。不要预创建 `/dm8/data` 等任何子目录。

### 1.3 提取安装器（安装器/介质不能放 dmdba 无权读取的目录）

```bash
mount -o loop dm8_*.iso /mnt && cp /mnt/DMInstall.bin /home/dmdba/ && umount /mnt
chmod +x /home/dmdba/DMInstall.bin
cp dmE301208192.key /home/dmdba/
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
<KEY>/home/dmdba/dmE301208192.key</KEY>
<INSTALL_TYPE>0</INSTALL_TYPE>            <!-- 0=全部组件 -->
<INSTALL_PATH>/dm8</INSTALL_PATH>
<INIT_DB>Y</INIT_DB>                       <!-- 随装初始化实例 -->
<CREATE_DB_SERVICE>N</CREATE_DB_SERVICE>   <!-- 非 root 必须 N -->
<DB_PARAMS>
<PATH>/dm8/data</PATH>
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
> 真正成功判据：`/dm8/bin/dmserver` 与 `/dm8/data/DAMENG/dm.ini` 同时存在，
> dmdba 日志尾部出现 `[INFO] 安装达梦数据库完成。` 和 `[INFO] 初始化数据库完成。`

### 1.6 root 收尾 + 服务注册 + 启动

```bash
/dm8/script/root/root_installer.sh                        # 注册 DmAPService
/dm8/script/root/dm_service_installer.sh -t dmserver \
      -dm_ini /dm8/data/DAMENG/dm.ini -p DMSERVER          # 注册实例服务
systemctl enable --now DmServiceDMSERVER DmAPService
ss -ltn | grep 5236                                        # 监听验证
```

### 1.7 验证（disql）

```bash
# 密码含 @ 时必须整体加引号，否则连接串解析错乱
/dm8/bin/disql 'SYSDBA/"PHMadmin1"@localhost:5236'
SQL> SELECT INSTANCE_NAME FROM V$INSTANCE;   -- DMSERVER
SQL> SELECT EXPIRED_DATE FROM V$LICENSE;     -- 2027-06-25（key 生效）
```

### 1.8 替换式重建实例（2026-09-16 实录，当前设备即此形态）

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

## 二、Qt 5.14.2 QDM 驱动编译部署（实录步骤）

### 2.1 思路

达梦无 Qt 二进制驱动，官方源码包 `qt_src-*.zip` 内含 dm_48/dm_56/dm_57/dm5.12 多套源码，
**Qt 5.14 用 dm5.12 目录**。驱动经 DPI（`libdmdpi.so`）直连数据库，无需 ODBC。
产物 `libqsqldm.so` 放入 Qt 插件目录，Qt 驱动名 **`QDM`**。

### 2.2 依赖

- DPI 头文件：`/dm8/include/DPI*.h`（随 DM8 安装已有）
- DPI 库：`/dm8/drivers/dpi/libdmdpi.so`
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
/opt/Qt5.14.2/bin/qmake "INCLUDEPATH+=/dm8/include" \
      "LIBPATH+=/dm8/drivers/dpi" "DEFINES+=DM64" ../dm.pro
make -j$(nproc)
```

> ⚠️ **坑 5**：make 的 DESTDIR 是坏路径，产物会被 mv 到根下 `/plugins/sqldrivers/`。
> 构建后 `find` 定位 `libqsqldm.so` 再手工安装。

### 2.4 安装 + 运行时寻址

```bash
cp <产物路径>/libqsqldm.so /opt/Qt5.14.2/plugins/sqldrivers/

# ⚠️ 坑 6：libdmdpi.so 不在系统库路径，Qt 程序加载插件会失败。系统级注册：
printf "/dm8/drivers/dpi\n/dm8/drivers/odbc/dependencies\n" > /etc/ld.so.conf.d/dm8.conf
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
```

脚本特性：

- **幂等可重跑**：DM8 已装（`/dm8/bin/dmserver` 存在）跳过安装只做服务/连通检查；
  QDM 插件已存在跳过编译。失败修复后直接重跑。
- 全自动：SHA256 校验 → loop 挂载提取安装器 → 用户/限额/空目录 → 静默安装（正确 XML 含
  CREATE_DB_SERVICE=N）→ root 脚本注册服务 → 启动 → disql 验证（含 License 到期日）
  → ldconfig → QDM 编译安装 → **Qt 端到端冒烟**（真实建表/插中文/查询/删表）→ 清理。
- 无 `unzip` 自动回退 `python3 -m zipfile`。
- 每阶段 `[阶段N] [OK]/[FAIL]` 输出，失败即停并给定位提示。
- 本文所有坑（空目录、CREATE_DB_SERVICE、Windows 残留行、坏 DESTDIR、ldconfig、disql 引号）
  已全部内置规避。

## 五、坑清单速查（人工部署对照）

| # | 坑 | 规避 |
|---|---|---|
| 1 | 安装目录非空 → 静默失败且 RC=0 | `/dm8` 全空，成功判据看产物文件 |
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

> **dmPython 集成（2026-09-16 起）**：`sudo env PYTHON_VENV=/path/to/venv bash install_dm8_qt.sh ...` 自动执行：离线装 `wheels/dmpython-*.whl`（已可导入则跳过）→ 拷 crypto 库修 -70089 → **干净环境连接验证**。未设 PYTHON_VENV 则提示跳过。详见《dmPython连接配置方案.md》。

> **Python3.12+SSL 支撑（2026-09-16 起）**：脚本阶段 8c 自动检测 `/usr/local/bin/python3.12` 的 `import ssl`，失败时：离线安装 `debs/` 里 10 个编译依赖包（libssl-dev/libffi-dev/sqlite 等，已装自动跳过）→ 用包内 `Python-3.12.14.tgz` 重编安装（3.12 系列 ABI 兼容，venv/site-packages 不受影响）→ 验证 `_ssl`。`PY_FIX_SSL=skip` 可禁用。设备已有源码树时也可手工增量 `make`（见《dmPython连接配置方案.md》背景）。

> **客户需求对齐（2026-09-16）**：Python 以客户基准 **3.12.2** 编译，命令逐字对齐客户文档（`./configure --enable-optimizations --prefix=/usr/local` + `make -j$(nproc)` + `sudo make altinstall`；PGO 构建约 30~60 分钟）。基础工具 build-essential/gcc/g++/make/curl 设备已有，wget 已入 debs/。**PyCharm 与 CAN 调试助手经确认不安装**。sqlite3 CLI 已入 debs/（universe 池，3.31.1；目标设备本就已安装）。

## 六、真机 E2E 验证记录（2026-09-16）

部署包已在目标设备（kylin@192.168.1.222）全脚本实跑通过，逐阶段结果：DM8 幂等跳过→disql/LICENSE→DPI 注册→QDM→**Qt↔DM 中文冒烟通过**→dmPython 干净环境连接通过→Python _ssl 验证→清理，全绿。原始日志见 `验证记录/`。重启后复查：达梦双服务 active+5236 监听+disql OPEN+python _ssl 正常，均开机自启级稳定。修复记录：PY_FIX_SSL 变量缺省值 bug（set -u 下崩溃）已修。

## 七、客户新增 Python 依赖（numpy / pandas / statsmodels / openpyxl）

客户在目标设备的 Python 3.12 环境新增四个依赖：**numpy、pandas、statsmodels、openpyxl**。
目标环境与部署包主体相同：**aarch64（飞腾）/ 麒麟 V10 SP1 / 离线内网**，无公网 pip 源，只能 wheelhouse 摆渡。

### 7.1 现状边界（先读）

- `install_dm8_qt.sh` 当前**只自动安装 dmPython**（`wheels/dmpython-*.whl`），**不会安装这四个依赖**。
- 对应 wheelhouse **尚未随部署包提供**（`wheels/` 目录现仅含 dmpython 一个 wheel）。
- 因此本节四包需按下述流程人工准备与安装；后续 wheelhouse 随包提供后再议脚本自动化。

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
