#!/usr/bin/env bash
# =============================================================================
# 达梦 DM8 + Qt QDM 驱动 一键部署脚本（飞腾 ARM64 / 麒麟 V10 SP1 / 离线内网）
#
# 用法:
#   sudo bash install_dm8_qt.sh [dm8介质目录]     # 目录须含 iso/SHA256/key/qt_src.zip
#
# 可选环境变量（均有默认值）:
#   SYSDBA_PWD        SYSDBA 密码        默认 PHMadmin1        （须8~48位,含大写+小写+数字）
#   SYSAUDITOR_PWD    SYSAUDITOR 密码    默认 Dameng@Audit2026
#   PHMAPP_PWD        PHM 业务账号密码   默认 PHMapp2026       （须8~48位,含大写+小写+数字）
#   DM_CHARSET        0=GB18030 1=UTF-8  默认 0   （建库后不可改！）
#   DM_CASE_SENSITIVE Y/N                默认 Y   （建库后不可改！）
#   DM_HOME           DM安装目录         默认 /dm8
#   PORT_NUM          实例端口           默认 5236
#   QT_HOME           Qt SDK 目录        默认 /opt/Qt5.14.2
#   QT_SRC            qt5 模块源码树     默认 /home/kylin/qt5
#   PYTHON_VENV       目标 venv 路径     默认空(跳过 dmPython 阶段)；设置后自动装 wheel+修 -70089+验证
#   PY_FIX_SSL        是否修复/构建 Python3.12 _ssl  默认 auto（检测到 import ssl 失败才执行）
#
# 特性: 幂等可重跑（DM已装跳过安装, 插件已装跳过编译）; 失败即停并提示。
# 详细过程与坑位说明见同目录 INSTALL.md
# =============================================================================
set -uo pipefail

# ---------- 可调参数 ----------
SYSDBA_PWD="${SYSDBA_PWD:-PHMadmin1}"
SYSAUDITOR_PWD="${SYSAUDITOR_PWD:-Dameng@Audit2026}"
PHMAPP_PWD="${PHMAPP_PWD:-PHMapp2026}"
DM_CHARSET="${DM_CHARSET:-0}"
DM_CASE_SENSITIVE="${DM_CASE_SENSITIVE:-Y}"
DM_HOME="${DM_HOME:-/dm8}"
DATA_PATH="${DATA_PATH:-$DM_HOME/data}"
DB_NAME="${DB_NAME:-DAMENG}"
INSTANCE_NAME="${INSTANCE_NAME:-DMSERVER}"
PORT_NUM="${PORT_NUM:-5236}"
PAGE_SIZE="${PAGE_SIZE:-8}"
QT_HOME="${QT_HOME:-/opt/Qt5.14.2}"
QT_SRC="${QT_SRC:-/home/kylin/qt5}"
PYTHON_VENV="${PYTHON_VENV:-}"
PY_FIX_SSL="${PY_FIX_SSL:-auto}"
DMDBA_HOME="/home/dmdba"

# ---------- 日志 ----------
C_G="\033[32m"; C_R="\033[31m"; C_Y="\033[33m"; C_0="\033[0m"
info()  { printf "${C_G}[OK]${C_0}  %s\n" "$*"; }
warn()  { printf "${C_Y}[WARN]${C_0} %s\n" "$*"; }
fail()  { printf "${C_R}[FAIL]${C_0} %s\n" "$*"; exit 1; }
stage() { printf "\n${C_G}========== [阶段%s] %s ==========${C_0}\n" "$1" "$2"; }

# ---------- 全局 ----------
DM_DIR=""
MOUNT_POINT=$(mktemp -d /tmp/dm8iso.XXXXXX)
cleanup() { mountpoint -q "$MOUNT_POINT" 2>/dev/null && umount "$MOUNT_POINT"; rmdir "$MOUNT_POINT" 2>/dev/null; }
trap cleanup EXIT

# =============================================================================
stage 0 "预检"
# =============================================================================
[ "$(id -u)" -eq 0 ] || fail "请用 root（sudo）运行本脚本"
ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] || warn "当前架构 $ARCH 非 aarch64，本 ISO 为飞腾 ARM64 专用，安装器将校验失败"
command -v sha256sum >/dev/null || fail "缺少 sha256sum"
command -v python3 >/dev/null || command -v unzip >/dev/null || fail "缺少 unzip 或 python3（解压 qt_src 需要）"

DM_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
[ -d "$DM_DIR" ] || fail "dm8 介质目录不存在: $DM_DIR"
DM_DIR=$(cd "$DM_DIR" && pwd)
info "介质目录: $DM_DIR"

ISO=$(ls "$DM_DIR"/dm8_*_FTarm_*_64.iso 2>/dev/null | head -1)
KEY=$(ls "$DM_DIR"/dm*.key 2>/dev/null | head -1)
QTZIP=$(ls "$DM_DIR"/qt_src-*.zip 2>/dev/null | head -1)
SHA_FILE=$(ls "$DM_DIR"/*.iso_SHA256.txt 2>/dev/null | head -1)

# dm.ini 位置兼容两种布局：随装初始化($DATA_PATH/$DB_NAME/dm.ini)与
# 独立 dminit 重建($DATA_PATH/$DB_NAME/$DB_NAME/dm.ini，dminit 会追加库名子目录)
find_dm_ini() {
  DM_INI=""
  local p
  for p in "$DATA_PATH/$DB_NAME/dm.ini" "$DATA_PATH/$DB_NAME/$DB_NAME/dm.ini"; do
    [ -f "$p" ] && { DM_INI="$p"; return 0; }
  done
  return 1
}
DM_INSTALLED=0; QDM_INSTALLED=0
[ -x "$DM_HOME/bin/dmserver" ] && find_dm_ini && DM_INSTALLED=1
[ -f "$QT_HOME/plugins/sqldrivers/libqsqldm.so" ] && QDM_INSTALLED=1

[ "$DM_INSTALLED" -eq 1 ] || [ -n "$ISO" ] || fail "介质目录无 ISO 且 $DM_HOME 未安装过 DM8，无法继续"
[ -n "$KEY" ]  || fail "未找到 license key 文件 (dm*.key)"
[ -n "$QTZIP" ] || fail "未找到 qt_src-*.zip"

# 密码策略校验
check_pwd() {
  local p="$1" n="$2"
  [ ${#p} -ge 8 ] && [ ${#p} -le 48 ] || fail "$n 长度须 8~48"
  [[ "$p" =~ [A-Z] ]] || fail "$n 须包含大写字母"
  [[ "$p" =~ [a-z] ]] || fail "$n 须包含小写字母"
  [[ "$p" =~ [0-9] ]] || fail "$n 须包含数字"
  case "$p" in *'"'*|*'\'*) fail "$n 含引号/反斜杠，转义不兼容，请更换" ;; esac
}
check_pwd "$SYSDBA_PWD" "SYSDBA_PWD"
check_pwd "$SYSAUDITOR_PWD" "SYSAUDITOR_PWD"
case "$DM_CHARSET" in 0|1) ;; *) fail "DM_CHARSET 只能 0(GB18030) 或 1(UTF-8)" ;; esac
case "$DM_CASE_SENSITIVE" in Y|y|N|n) ;; *) fail "DM_CASE_SENSITIVE 只能 Y/N" ;; esac
info "预检通过 (DM已装=$DM_INSTALLED, QDM已装=$QDM_INSTALLED)"

# =============================================================================
if [ "$DM_INSTALLED" -eq 0 ]; then

stage 1 "ISO 校验"
# =============================================================================
if [ -n "$SHA_FILE" ]; then
  EXPECT=$(grep -oE '[0-9a-fA-F]{64}' "$SHA_FILE" | head -1)
  ACTUAL=$(sha256sum "$ISO" | awk '{print $1}')
  [ "$EXPECT" = "$ACTUAL" ] || fail "ISO SHA256 不匹配！介质损坏，请重新拷贝"
  info "SHA256 校验一致"
else
  warn "介质目录无 SHA256 文件，跳过校验"
fi

# =============================================================================
stage 2 "系统准备（dmdba/资源限制/空安装目录）"
# =============================================================================
groupadd -f dinstall
id dmdba >/dev/null 2>&1 || useradd -g dinstall -m -s /bin/bash dmdba
grep -q "^dmdba " /etc/security/limits.conf || printf \
"dmdba soft nofile 65536\ndmdba hard nofile 65536\ndmdba soft nproc 65536\ndmdba hard nproc 65536\n" \
>> /etc/security/limits.conf
mkdir -p "$DM_HOME"
chown dmdba:dinstall "$DM_HOME"
if [ -n "$(ls -A "$DM_HOME" 2>/dev/null)" ]; then
  fail "$DM_HOME 非空，DM 静默安装要求空目录（残留旧安装请先备份清空再重跑）"
fi
info "系统准备完成"

# =============================================================================
stage 3 "提取安装器并静默安装（约5~10分钟）"
# =============================================================================
mount -o loop "$ISO" "$MOUNT_POINT" || fail "loop 挂载 ISO 失败（检查内核 loop 设备支持）"
cp "$MOUNT_POINT/DMInstall.bin" "$DMDBA_HOME/" || { umount "$MOUNT_POINT"; fail "ISO 中未找到 DMInstall.bin"; }
umount "$MOUNT_POINT"
cp "$KEY" "$DMDBA_HOME/dm.key.src"
chown dmdba:dinstall "$DMDBA_HOME/DMInstall.bin" "$DMDBA_HOME/dm.key.src"
chmod +x "$DMDBA_HOME/DMInstall.bin"

cat > "$DMDBA_HOME/auto_install.xml" <<EOF
<?xml version="1.0"?>
<DATABASE>
<LANGUAGE>ZH</LANGUAGE>
<TIME_ZONE>+08:00</TIME_ZONE>
<KEY>$DMDBA_HOME/dm.key.src</KEY>
<INSTALL_TYPE>0</INSTALL_TYPE>
<INSTALL_PATH>$DM_HOME</INSTALL_PATH>
<INIT_DB>Y</INIT_DB>
<CREATE_DB_SERVICE>N</CREATE_DB_SERVICE>
<DB_PARAMS>
<PATH>$DATA_PATH</PATH>
<DB_NAME>$DB_NAME</DB_NAME>
<INSTANCE_NAME>$INSTANCE_NAME</INSTANCE_NAME>
<PORT_NUM>$PORT_NUM</PORT_NUM>
<PAGE_SIZE>$PAGE_SIZE</PAGE_SIZE>
<CASE_SENSITIVE>$DM_CASE_SENSITIVE</CASE_SENSITIVE>
<CHARSET>$DM_CHARSET</CHARSET>
<SYSDBA_PWD>$SYSDBA_PWD</SYSDBA_PWD>
<SYSAUDITOR_PWD>$SYSAUDITOR_PWD</SYSAUDITOR_PWD>
</DB_PARAMS>
</DATABASE>
EOF
chown dmdba:dinstall "$DMDBA_HOME/auto_install.xml"

INSTALL_LOG="$DMDBA_HOME/dm_install_$(date +%Y%m%d_%H%M%S).log"
echo "安装日志: $INSTALL_LOG"
su - dmdba -c "cd $DMDBA_HOME && ./DMInstall.bin -q $DMDBA_HOME/auto_install.xml" > "$INSTALL_LOG" 2>&1
if [ ! -x "$DM_HOME/bin/dmserver" ] || ! find_dm_ini; then
  echo "----- 安装日志关键行 -----"
  tail -c 2000 "$INSTALL_LOG" | tr -d '.' | grep -aE "[一-龥]|rror|ail" | tail -8
  fail "静默安装未产出预期文件（常见: 目录非空/架构不符/key无效），见上方日志"
fi
info "DM8 安装与实例初始化完成"

# =============================================================================
stage 4 "注册并启动服务"
# =============================================================================
bash "$DM_HOME/script/root/root_installer.sh" >/dev/null 2>&1 || warn "root_installer.sh 返回非0（服务已存在时可忽略）"
if [ ! -f "/lib/systemd/system/DmService$INSTANCE_NAME.service" ] && [ ! -f "/etc/systemd/system/DmService$INSTANCE_NAME.service" ]; then
  bash "$DM_HOME/script/root/dm_service_installer.sh" -t dmserver -dm_ini "$DM_INI" -p "$INSTANCE_NAME" \
    || fail "实例服务注册失败"
fi
systemctl enable --now "DmService$INSTANCE_NAME" >/dev/null 2>&1
sleep 4
systemctl is-active --quiet "DmService$INSTANCE_NAME" || fail "DmService$INSTANCE_NAME 未运行"
ss -ltn 2>/dev/null | grep -q ":$PORT_NUM " || fail "端口 $PORT_NUM 未监听"
info "服务运行中，端口 $PORT_NUM 监听正常"

else
stage 1-4 "检测到 DM8 已安装，跳过安装阶段"
systemctl enable --now "DmService$INSTANCE_NAME" >/dev/null 2>&1 || true
systemctl is-active --quiet "DmService$INSTANCE_NAME" || fail "DmService$INSTANCE_NAME 未运行，请手动 systemctl start 排查"
ss -ltn 2>/dev/null | grep -q ":$PORT_NUM " || fail "端口 $PORT_NUM 未监听"
info "已有实例运行正常"
fi

# =============================================================================
stage 5 "disql 连通性与授权验证"
# =============================================================================
DM_DISQL="$DM_HOME/bin/disql"
[ -x "$DM_DISQL" ] || DM_DISQL=$(find "$DM_HOME" -name disql -type f 2>/dev/null | head -1)
[ -n "$DM_DISQL" ] || fail "未找到 disql"
DSN="SYSDBA/\"$SYSDBA_PWD\"@localhost:$PORT_NUM"
RESULT=$(printf '%s\nexit\n' 'SELECT INSTANCE_NAME FROM V$INSTANCE;' | "$DM_DISQL" "$DSN" 2>&1)
echo "$RESULT" | grep -q "$INSTANCE_NAME" || fail "disql 验证失败（密码错误或实例未就绪）: $(echo "$RESULT" | tail -2 | tr '\n' ' ')"
EXPIRE=$(printf '%s\nexit\n' 'SELECT EXPIRED_DATE FROM V$LICENSE;' | "$DM_DISQL" "$DSN" 2>&1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
info "disql 连通 OK，实例=$INSTANCE_NAME，License到期=${EXPIRE:-未知}"

# =============================================================================
stage 6 "DPI 运行库系统注册"
# =============================================================================
if [ ! -f /etc/ld.so.conf.d/dm8.conf ]; then
  printf "%s\n%s\n" "$DM_HOME/drivers/dpi" "$DM_HOME/drivers/odbc/dependencies" > /etc/ld.so.conf.d/dm8.conf
fi
ldconfig
info "libdmdpi.so 已注册系统库路径"

# =============================================================================
stage 7 "Qt QDM 驱动编译安装"
# =============================================================================
if [ "$QDM_INSTALLED" -eq 1 ]; then
  info "libqsqldm.so 已存在，跳过编译"
else
  if [ ! -x "$QT_HOME/bin/qmake" ]; then
    warn "未找到 $QT_HOME/bin/qmake，跳过 Qt 驱动阶段（Qt SDK 就绪后重跑本脚本即可）"
    exit 0
  fi
  if [ ! -f "$QT_SRC/qtbase/src/plugins/sqldrivers/qsqldriverbase.pri" ]; then
    warn "未找到 qtbase 源码树 $QT_SRC（编译依赖 qsqldriverbase.pri），跳过 Qt 驱动阶段"
    exit 0
  fi

  WORK=$(mktemp -d /tmp/dmqt.XXXXXX)
  if command -v unzip >/dev/null; then
    unzip -q "$QTZIP" -d "$WORK"
  else
    python3 -m zipfile -e "$QTZIP" "$WORK/"
  fi
  DM5_DIR=$(ls -d "$WORK"/qt_src*/plugins_sqldrivers/dm5.12 2>/dev/null | head -1)
  [ -n "$DM5_DIR" ] || { rm -rf "$WORK"; fail "qt_src 包内未找到 plugins_sqldrivers/dm5.12"; }

  DST="$QT_SRC/qtbase/src/plugins/sqldrivers/dm"
  rm -rf "$DST"; mkdir -p "$DST"
  cp "$DM5_DIR"/dm.pro "$DM5_DIR"/main.cpp "$DM5_DIR"/qsql_dm.cpp "$DM5_DIR"/qsql_dm.pri "$DM5_DIR"/qsql_dm_p.h "$DM5_DIR"/dm.json "$DST/" 2>/dev/null
  cd "$DST" || fail "无法进入 $DST"
  sed -i '/dm7_20210303/d' dm.pro          # 坑4: 删硬编码 Windows 路径行
  rm -f dm.pro.user
  rm -rf build; mkdir build; cd build || fail "build 目录创建失败"
  "$QT_HOME/bin/qmake" "INCLUDEPATH+=$DM_HOME/include" "LIBPATH+=$DM_HOME/drivers/dpi" "DEFINES+=DM64" ../dm.pro \
    || fail "qmake 失败"
  make -j"$(nproc)" >/dev/null 2>&1 || make || fail "QDM 编译失败"
  # 坑5: DESTDIR 是坏路径，产物可能落在 /plugins —— find 兜底定位
  SO=$(find "$DST/build" /plugins -maxdepth 4 -name libqsqldm.so -type f 2>/dev/null | head -1)
  [ -n "$SO" ] || fail "编译后未找到 libqsqldm.so"
  install -m 755 "$SO" "$QT_HOME/plugins/sqldrivers/libqsqldm.so"
  [ -d /plugins ] && rm -rf /plugins        # 清理坏 DESTDIR 残留（非标准FS路径）
  rm -rf "$WORK"
  if ldd "$QT_HOME/plugins/sqldrivers/libqsqldm.so" 2>/dev/null | grep -q "not found"; then
    fail "libqsqldm.so 存在未解析依赖（检查阶段6 ldconfig）"
  fi
  info "QDM 驱动已安装: $QT_HOME/plugins/sqldrivers/libqsqldm.so"
fi

# =============================================================================
stage 8 "Qt 端到端冒烟验证（建表/插中文/查询/清理）"
# =============================================================================
SMOKE=$(mktemp -d /tmp/dmqsmoke.XXXXXX) || fail "创建冒烟目录失败"
cd "$SMOKE" || fail "无法进入冒烟目录"
cat > main.cpp <<'CPPEOF'
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
int main(int c, char **v) {
    QCoreApplication a(c, v);
    QSqlDatabase db = QSqlDatabase::addDatabase("QDM");
    db.setHostName("localhost");
    db.setPort(PORT_NUM);
    db.setUserName("SYSDBA");
    db.setPassword("PWD_STR");
    db.setDatabaseName("DB_NAME_STR");
    if (!db.open()) { qDebug() << "OPEN_FAIL:" << db.lastError().text(); return 1; }
    QSqlQuery q(db);
    q.exec("DROP TABLE dmqsmoke");
    if (!q.exec("CREATE TABLE dmqsmoke(id INT, name VARCHAR(100))")) { qDebug() << "CREATE_FAIL:" << q.lastError().text(); return 2; }
    q.prepare("INSERT INTO dmqsmoke VALUES(?,?)");
    q.addBindValue(1); q.addBindValue(QString::fromUtf8("一键部署冒烟测试"));
    q.exec();
    q.exec("SELECT id,name FROM dmqsmoke");
    while (q.next()) qDebug() << "ROW:" << q.value(0).toInt() << q.value(1).toString();
    q.exec("DROP TABLE dmqsmoke");
    qDebug() << "QT_DM_SMOKE_OK";
    return 0;
}
CPPEOF
sed -i "s/PORT_NUM/$PORT_NUM/; s/DB_NAME_STR/$DB_NAME/; s/PWD_STR/$SYSDBA_PWD/" main.cpp
printf 'TEMPLATE=app\nQT+=sql\nSOURCES+=main.cpp\n' > smoke.pro
"$QT_HOME/bin/qmake" smoke.pro >/dev/null 2>&1 && make -j"$(nproc)" >/dev/null 2>&1
if [ ! -x ./smoke ]; then rm -rf "$SMOKE"; fail "冒烟程序编译失败（Qt 环境异常）"; fi
OUT=$(./smoke 2>&1)
rm -rf "$SMOKE"
if echo "$OUT" | grep -q "QT_DM_SMOKE_OK"; then
  info "Qt↔DM8 全链路验证通过（含中文存取）"; echo "$OUT" | grep "ROW:"
else
  fail "Qt 冒烟失败: $(echo "$OUT" | tr '\n' ' ')"
fi

# =============================================================================
stage 8b "dmPython 安装与 -70089 修复（可选：PYTHON_VENV=<venv路径>）"
# =============================================================================
if [ -z "$PYTHON_VENV" ]; then
  warn "未设置 PYTHON_VENV，跳过 dmPython 阶段（启用: sudo env PYTHON_VENV=/path/to/venv bash $0 ...）"
elif [ ! -x "$PYTHON_VENV/bin/python" ]; then
  warn "PYTHON_VENV 下无 bin/python（非有效 venv），跳过"
else
  VOWNER=$(stat -c %U "$PYTHON_VENV" 2>/dev/null || echo root)
  run_as_owner() { if [ "$VOWNER" = "root" ]; then "$@"; else sudo -n -u "$VOWNER" "$@"; fi; }
  if "$PYTHON_VENV/bin/python" -c "import dmPython" >/dev/null 2>&1; then
    info "dmPython 已可导入，仅补 crypto 库"
  else
    WHEEL=$(ls "$DM_DIR"/wheels/dmpython-*.whl 2>/dev/null | head -1)
    if [ -n "$WHEEL" ]; then
      run_as_owner "$PYTHON_VENV/bin/pip" install --no-index "$WHEEL" \
        || fail "dmPython wheel 安装失败（wheel 与 venv 的 python 版本/架构不匹配）"
      info "已离线安装 $(basename "$WHEEL")"
    else
      run_as_owner "$PYTHON_VENV/bin/pip" install dmpython \
        || fail "dmPython 在线安装失败（离线设备请把 dmpython-*.whl 放入 $DM_DIR/wheels/）"
    fi
  fi
  DMPY_LIBS=$(find "$PYTHON_VENV/lib" -type d -name dmpython.libs 2>/dev/null | head -1)
  [ -n "$DMPY_LIBS" ] || fail "未找到 dmpython.libs 目录（wheel 结构异常）"
  run_as_owner cp "$DM_HOME/drivers/odbc/dependencies/libcrypto.so" \
                    "$DM_HOME/drivers/odbc/dependencies/libssl.so" "$DMPY_LIBS/"
  # 关键验证：干净环境（无任何 LD_LIBRARY_PATH）连接 —— 即 systemd/gunicorn 部署形态
  if env -i PATH=/usr/bin:/bin "$PYTHON_VENV/bin/python" -c "
import dmPython
c = dmPython.connect(user='SYSDBA', password='$SYSDBA_PWD', server='127.0.0.1', port=$PORT_NUM)
print('PY_DM_OK')
c.close()" 2>/dev/null | grep -q "PY_DM_OK"; then
    info "dmPython 干净环境连接验证通过（-70089 已根治）"
  else
    fail "dmPython 干净环境连接失败（检查 crypto 库是否已拷入 $DMPY_LIBS）"
  fi
fi

# =============================================================================
stage 8c "Python3.12 + SSL 支撑（debs 离线安装 + _ssl 修复构建）"
# =============================================================================
PY312=/usr/local/bin/python3.12
if [ "$PY_FIX_SSL" = "skip" ]; then
  warn "PY_FIX_SSL=skip，跳过 Python/SSL 阶段"
elif [ -x "$PY312" ] && "$PY312" -c "import ssl" >/dev/null 2>&1; then
  info "python3.12 的 _ssl 正常，跳过"
else
  # 1) 离线安装开发包（已装则跳过，避免降级）
  TODO_DEBS=""
  for d in "$DM_DIR"/debs/*.deb; do
    [ -f "$d" ] || continue
    pn=$(dpkg-deb -f "$d" Package 2>/dev/null) || continue
    if dpkg-query -W -f'${Status}' "$pn" 2>/dev/null | grep -q "install ok installed"; then continue; fi
    TODO_DEBS="$TODO_DEBS $d"
  done
  if [ -n "$TODO_DEBS" ]; then
    dpkg -i $TODO_DEBS >/dev/null 2>&1 || fail "dev 包安装失败（见上方 dpkg 输出）"
    info "已离线安装：$(echo $TODO_DEBS | xargs -n1 basename | tr '\n' ' ')"
  else
    info "dev 包均已安装"
  fi
  [ -f /usr/include/openssl/ssl.h ] || fail "缺 /usr/include/openssl/ssl.h（libssl-dev 异常），无法构建 _ssl"
  # 2) 找源码包并构建（3.12 系列 ABI 兼容，补丁版本覆盖安全；venv/site-packages 不受影响）
  PYTGZ=$(ls "$DM_DIR"/Python-3.12*.tgz 2>/dev/null | head -1)
  [ -n "$PYTGZ" ] || fail "未找到 $DM_DIR/Python-3.12*.tgz，无法重编 Python（设备已有源码树可手工增量 make）"
  if [ -x "$PY312" ]; then
    CURV=$($PY312 -V 2>&1 | awk '{print $2}')
    NEWV=$(basename "$PYTGZ" | sed 's/Python-//; s/.tgz//')
    CURMINOR=$(echo "$CURV" | cut -d. -f2)
    [ "$CURMINOR" = "12" ] || fail "现有 $PY312 非 3.12 系列（$CURV），与源码包不匹配，中止"
    warn "将以 $NEWV 覆盖当前 $CURV（3.12 系列 ABI 兼容，venv/第三方包不受影响）"
  fi
  info "开始构建 Python（客户标准：--enable-optimizations + altinstall，PGO 构建约 30~60 分钟）：$(basename "$PYTGZ")"
  PYSRC=$(mktemp -d /tmp/pybuild.XXXXXX)
  tar xzf "$PYTGZ" -C "$PYSRC"
  cd "$PYSRC"/Python-* || fail "解压失败"
  ./configure --enable-optimizations --prefix=/usr/local >/tmp/py_configure.log 2>&1 \
    || { tail -5 /tmp/py_configure.log; fail "configure 失败"; }
  make -j"$(nproc)" >/tmp/py_make.log 2>&1 || { tail -8 /tmp/py_make.log; fail "make 失败（日志 /tmp/py_make.log）"; }
  make altinstall >/tmp/py_install.log 2>&1 || fail "make altinstall 失败"
  cd - >/dev/null; rm -rf "$PYSRC"
  "$PY312" -c "import ssl,hashlib" >/dev/null 2>&1 \
    || fail "构建后 import ssl 仍失败（查看 /tmp/py_make.log 末尾 missing 模块清单）"
  info "python3.12 _ssl 构建完成（$(basename "$PYTGZ")）"
fi

# =============================================================================
stage 8d "python3/pip3 默认化（指向 3.12）"
# =============================================================================
if [ ! -x "$PY312" ]; then
  fail "缺 $PY312（stage 8c 应已保证；PY_FIX_SSL=skip 时需先装好 Python3.12 再跑本阶段）"
elif [ ! -x /usr/local/bin/pip3.12 ]; then
  fail "缺 /usr/local/bin/pip3.12（python3.12 构建须含 ensurepip，否则 pip3 会成悬空链接）"
elif [ "$(readlink /usr/local/bin/python3 2>/dev/null)" = "$PY312" ] \
  && [ "$(readlink /usr/local/bin/pip3 2>/dev/null)" = "/usr/local/bin/pip3.12" ]; then
  info "python3/pip3 已指向 3.12，跳过"
else
  ln -sf "$PY312" /usr/local/bin/python3
  ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip3
  info "python3/pip3 已默认指向 3.12（系统 /usr/bin/python3 刻意不动，防破坏麒麟系统工具）"
fi

# =============================================================================
stage 8e "libGL 开发链（libgl-dev 解包落位）"
# =============================================================================
GL_LIB=/usr/lib/aarch64-linux-gnu/libGL.so
if [ -e "$GL_LIB" ] || [ -L "$GL_LIB" ]; then
  info "libGL.so 开发链接件已存在，跳过"
else
  GL_DEB=$(ls "$DM_DIR"/debs/libgl-dev_*.deb 2>/dev/null | head -1)
  [ -n "$GL_DEB" ] || fail "未找到 $DM_DIR/debs/libgl-dev_*.deb（按 INSTALL.md §五制备补齐）"
  # 禁 dpkg -i：libgl-dev 名义依赖拖 libx11-dev 九包链，离线不可解 → 只解包落位
  GL_TMP=$(mktemp -d /tmp/gldev.XXXXXX)
  dpkg-deb -x "$GL_DEB" "$GL_TMP" || { rm -rf "$GL_TMP"; fail "libgl-dev 解包失败: $GL_DEB"; }
  [ -d "$GL_TMP/usr" ] || { rm -rf "$GL_TMP"; fail "包内无 usr/ 树，结构非预期: $GL_DEB"; }
  # deb 内 libGL.so 是指向 libGL.so.1（运行时包，不在本 deb 内）的断链符号链接：存在性门必须容断链
  { [ -e "$GL_TMP/usr/lib/aarch64-linux-gnu/libGL.so" ] || [ -L "$GL_TMP/usr/lib/aarch64-linux-gnu/libGL.so" ]; } \
    || { rm -rf "$GL_TMP"; fail "包内缺 usr/lib/aarch64-linux-gnu/libGL.so（架构/布局不符）: $GL_DEB"; }
  chown -R root:root "$GL_TMP/usr"
  cp -a "$GL_TMP/usr/." / || { rm -rf "$GL_TMP"; fail "usr/ 整树拷入 / 失败"; }
  rm -rf "$GL_TMP"
  [ -e "$GL_LIB" ] || [ -L "$GL_LIB" ] || fail "拷入后仍未找到 $GL_LIB（deb 内容与预期不符）"
  info "libGL 开发链已落位（libGL.so 链接＋GL 头 gl.h/glcorearb.h/glext.h＋KHR＋pkgconfig）"
fi

# =============================================================================
stage 8f "venv 四包 numpy/pandas/statsmodels/openpyxl（可选：需 PYTHON_VENV）"
# =============================================================================
WH_CUST="$DM_DIR/wheels/wheelhouse-cust"
if [ -z "$PYTHON_VENV" ]; then
  warn "未设置 PYTHON_VENV，跳过四包阶段"
elif [ ! -x "$PYTHON_VENV/bin/python" ]; then
  warn "PYTHON_VENV 下无 bin/python（非有效 venv），跳过四包阶段"
else
  # 与 8b 同款降权：kylin 属主 venv 内安装/验证以属主执行，防 root 落属主文件卡死后续 kylin pip/import
  VOWNER=$(stat -c %U "$PYTHON_VENV" 2>/dev/null || echo root)
  run_as_owner() { if [ "$VOWNER" = "root" ]; then "$@"; else sudo -n -u "$VOWNER" "$@"; fi; }
  PIN4="numpy==2.5.4 pandas==3.1.1 statsmodels==0.15.0 openpyxl==3.1.5"
  for p in numpy pandas statsmodels openpyxl; do
    ls "$WH_CUST"/"$p"-*.whl >/dev/null 2>&1 \
      || fail "$WH_CUST 缺 ${p} 顶层 wheel（按 INSTALL.md §7 制备补齐）"
  done
  # 幂等门：四个精确 pin 全部就位才跳过（freeze 逐条全字匹配）
  if [ "$(run_as_owner "$PYTHON_VENV/bin/pip" freeze 2>/dev/null | grep -cE '^(numpy==2\.5\.4|pandas==3\.1\.1|statsmodels==0\.15\.0|openpyxl==3\.1\.5)$')" -eq 4 ]; then
    info "四包精确 pin 已就位，跳过安装"
  else
    run_as_owner "$PYTHON_VENV/bin/pip" install --no-index \
      --find-links "$DM_DIR/wheels" --find-links "$WH_CUST" $PIN4 \
      || fail "四包离线安装失败（wheel 与 venv python 版本/架构不匹配？）"
    info "四包已安装（传递依赖 11 个 wheel 由 pip 从 wheelhouse-cust 自解析）"
  fi
  run_as_owner "$PYTHON_VENV/bin/python" -c "import numpy,pandas,statsmodels,openpyxl" >/dev/null 2>&1 \
    || fail "venv 四包导入验证失败"
  run_as_owner "$PYTHON_VENV/bin/pip" check >/dev/null 2>&1 || fail "pip check 报告依赖问题"
  info "venv 四包验证通过（import + pip check）"
fi

# =============================================================================
stage 8g "PHM 业务面（PHMAPP 账号 + dm.ini + phm-app.service 落位）"
# =============================================================================
check_pwd "$PHMAPP_PWD" "PHMAPP_PWD"
# 语句里用户名走 UPPER('phmapp')：回显行只含小写，结果行才是大写 PHMAPP，grep 不误判
PHM_Q="SELECT USERNAME FROM DBA_USERS WHERE USERNAME = UPPER('phmapp');"
PHM_OUT=$(printf '%s\nexit\n' "$PHM_Q" | "$DM_DISQL" "$DSN" 2>&1)
if echo "$PHM_OUT" | grep -q "PHMAPP"; then
  info "数据库用户 PHMAPP 已存在，跳过建号"
else
  printf '%s\n%s\nexit\n' \
    "CREATE USER PHMAPP IDENTIFIED BY \"$PHMAPP_PWD\";" \
    "GRANT \"PUBLIC\", \"RESOURCE\" TO PHMAPP;" | "$DM_DISQL" "$DSN" >/dev/null 2>&1
  PHM_OUT=$(printf '%s\nexit\n' "$PHM_Q" | "$DM_DISQL" "$DSN" 2>&1)
  echo "$PHM_OUT" | grep -q "PHMAPP" \
    || fail "PHMAPP 建号失败（disql 手工执行排查）: $(echo "$PHM_OUT" | tail -2 | tr '\n' ' ')"
  info "已创建 PHMAPP"
fi
# 角色核验/补授：建号与已存在两路共用的终态门，防 GRANT 静默失败（PUBLIC 为隐含角色，只核 RESOURCE）
PHM_QR="SELECT GRANTED_ROLE FROM DBA_ROLE_PRIVS WHERE GRANTEE = UPPER('phmapp');"
PHM_ROLES=$(printf '%s\nexit\n' "$PHM_QR" | "$DM_DISQL" "$DSN" 2>&1)
if ! echo "$PHM_ROLES" | grep -q "RESOURCE"; then
  printf '%s\nexit\n' "GRANT \"PUBLIC\", \"RESOURCE\" TO PHMAPP;" | "$DM_DISQL" "$DSN" >/dev/null 2>&1
  PHM_ROLES=$(printf '%s\nexit\n' "$PHM_QR" | "$DM_DISQL" "$DSN" 2>&1)
  echo "$PHM_ROLES" | grep -q "RESOURCE" \
    || fail "PHMAPP 角色授予验证失败（RESOURCE 未生效）: $(echo "$PHM_ROLES" | tail -2 | tr '\n' ' ')"
  info "已补授 PHMAPP PUBLIC/RESOURCE"
fi
PHM_INI_DIR=/home/kylin/.config/phm
PHM_INI="$PHM_INI_DIR/dm.ini"
PHM_INI_TXT=$(printf '[dm]\nuser=PHMAPP\npassword=%s\nserver=127.0.0.1\nport=%s' "$PHMAPP_PWD" "$PORT_NUM")
if [ -f "$PHM_INI" ] && [ "$(cat "$PHM_INI")" = "$PHM_INI_TXT" ] && [ "$(stat -c %a "$PHM_INI")" = "600" ]; then
  info "$PHM_INI 已是目标形态，跳过"
else
  [ -d /home/kylin/.config ] || install -d -m 700 -o kylin -g kylin /home/kylin/.config
  mkdir -p "$PHM_INI_DIR"
  printf '%s\n' "$PHM_INI_TXT" > "$PHM_INI"
  chown kylin:kylin "$PHM_INI_DIR" "$PHM_INI" || fail "chown kylin 失败（设备缺 kylin 用户？PHM 业务面依赖该用户）"
  chmod 600 "$PHM_INI" || fail "chmod 600 失败: $PHM_INI"
  info "已写 $PHM_INI（属主 kylin，权限 600，四键 user/password/server/port）"
fi
PHM_SVC=/etc/systemd/system/phm-app.service
PHM_SVC_TXT=$(printf '[Unit]\nAfter=network.target DmService%s.service\n\n[Service]\nUser=kylin\nExecStart=/home/kylin/venvs/phm/bin/python /home/kylin/phm-app/main.py\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target' "$INSTANCE_NAME")
if [ -f "$PHM_SVC" ] && [ "$(cat "$PHM_SVC")" = "$PHM_SVC_TXT" ]; then
  info "phm-app.service 已是目标形态，跳过"
else
  printf '%s\n' "$PHM_SVC_TXT" > "$PHM_SVC"
  systemctl daemon-reload || fail "daemon-reload 失败"
  # 业务程序尚未部署，仅落位单元，刻意不 enable
  info "已落位 $PHM_SVC（未启用；业务程序部署后 systemctl enable --now phm-app）"
fi

# =============================================================================
stage 9 "清理"
# =============================================================================
rm -f "$DMDBA_HOME/DMInstall.bin" "$DMDBA_HOME/auto_install.xml" "$DMDBA_HOME/dm.key.src" 2>/dev/null
info "安装器临时文件已清理"

echo
printf "${C_G}================= 部署完成 =================${C_0}\n"
echo "数据库 : $DM_HOME  库=$DB_NAME 实例=$INSTANCE_NAME 端口=$PORT_NUM"
echo "服务   : systemctl {start|stop|restart} DmService$INSTANCE_NAME"
echo "登录   : $DM_HOME/bin/disql 'SYSDBA/\"$SYSDBA_PWD\"@localhost:$PORT_NUM'"
echo "Qt用法 : QSqlDatabase::addDatabase(\"QDM\")，工程加 QT += sql"
echo "Python : ${PYTHON_VENV:-未配置（PYTHON_VENV=<venv路径> 可启用 dmPython 阶段）}"
echo "PythonSSL: _ssl=$(/usr/local/bin/python3.12 -c 'import ssl;print(ssl.OPENSSL_VERSION)' 2>/dev/null || echo '异常(PY_FIX_SSL=auto 时应已修复)')"
echo "Py默认  : python3 → $(readlink /usr/local/bin/python3 2>/dev/null || echo '未默认化')"
echo "GL链    : $([ -e /usr/lib/aarch64-linux-gnu/libGL.so ] && echo 'libGL.so 开发链已落位' || echo '未落位')"
echo "PHM    : PHMAPP 账号就绪；dm.ini $([ -f /home/kylin/.config/phm/dm.ini ] && echo '已写' || echo '未写')；phm-app.service 落位未启用"
echo "License: 到期 ${EXPIRE:-见 /dm8/bin/dm.key}"
echo "注意   : CHARSET($DM_CHARSET)/CASE_SENSITIVE($DM_CASE_SENSITIVE) 建库后不可改；空库期可重建"
