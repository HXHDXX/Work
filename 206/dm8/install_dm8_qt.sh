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
#   DM_HOME           DM安装目录         默认 /opt/dm8（存量 /dm8 设备自动沿用）
#   LEGACY_DM_HOME    存量安装探测路径   默认 /dm8
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
# 判例 2026-11-20：dm8_20260312 构建的静默安装器要求 auto_install.xml 含非空 SYSSSO_PWD 节点，缺失报"配置文件SYSSSO_PWD节点字符串不能为空"（20260324 构建无此要求；.30 设备实测）
SYSSSO_PWD="${SYSSSO_PWD:-Dameng@Sso2026}"
PHMAPP_PWD="${PHMAPP_PWD:-PHMapp2026}"
DM_CHARSET="${DM_CHARSET:-0}"
DM_CASE_SENSITIVE="${DM_CASE_SENSITIVE:-Y}"
DM_HOME_WAS_SET="${DM_HOME+x}"
DM_HOME="${DM_HOME:-/opt/dm8}"
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
# --- dm-home adopt begin ---
# 布局候选须与 find_dm_ini 保持一致
# 存量设备沿用旧 /dm8 布局：仅用户未显式指定 DM_HOME 时探测；显式指定走全新安装语义（空目录校验兜底）
LEGACY_DM_HOME="${LEGACY_DM_HOME:-/dm8}"
if [ -z "${DM_HOME_WAS_SET:-}" ] && [ -x "$LEGACY_DM_HOME/bin/dmserver" ] \
  && { [ -f "$LEGACY_DM_HOME/data/${DB_NAME:-DAMENG}/dm.ini" ] || [ -f "$LEGACY_DM_HOME/data/${DB_NAME:-DAMENG}/${DB_NAME:-DAMENG}/dm.ini" ]; }; then
  DM_HOME="$LEGACY_DM_HOME"
  info "检测到存量 $LEGACY_DM_HOME 安装，沿用旧路径"
fi
# --- dm-home adopt end ---
DATA_PATH="${DATA_PATH:-$DM_HOME/data}"
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
# SYSSSO_PWD 同一密码策略校验（判例 2026-11-20：20260312 构建要求该节点，见默认值块注释）
check_pwd "$SYSSSO_PWD" "SYSSSO_PWD"
[ -n "$PYTHON_VENV" ] && [ ! -d "$PYTHON_VENV" ] && warn "PYTHON_VENV 目录不存在：$PYTHON_VENV（8c 将以 python3.12 代建；请核对路径拼写）"
case "$DM_CHARSET" in 0|1) ;; *) fail "DM_CHARSET 只能 0(GB18030) 或 1(UTF-8)" ;; esac
case "$DM_CASE_SENSITIVE" in Y|y|N|n) ;; *) fail "DM_CASE_SENSITIVE 只能 Y/N" ;; esac
# --- 编译器预检（判例 2026-11-19：2503 新镜像不带 g++，且 kylin g++-9 不注册 alternatives）---
if ! command -v g++ >/dev/null 2>&1; then
  GPP9=$(command -v g++-9 2>/dev/null || true)
  if [ -n "$GPP9" ]; then
    ln -sf "$GPP9" /usr/bin/g++ && info "已建 /usr/bin/g++ -> $GPP9"
  else
    fail "缺 g++（QDM 编译/冒烟需要）。修复：bash apt-tunnel.sh on 后 apt-get install -y g++；或离线装 g++-9+libstdc++-9-dev 后建软链"
  fi
fi
# --- KySec 预检（判例 2026-11-19：2503-update1 默认 enabled，拦截 kit 脚本执行，RC=126）---
# 完全关闭=两层，缺一不可（.30 实测）：setstatus disable 只关内核运行态，default 级别下
# 安全中心守护会把内核态重新拉起；security-switch --set custom --list "" 切级别总闸（空模块
# =框架整体不启用，重启保持）。裸 --set custom 报"参数错误"且不生效、重启即复活（2026-11-20 .30 重启实测）。
if command -v getstatus >/dev/null 2>&1 && getstatus 2>/dev/null | grep -q "^KySec status: enabled"; then
  setstatus disable >/dev/null 2>&1
  security-switch --set custom --list "" >/dev/null 2>&1
  getstatus 2>/dev/null | grep -q "^KySec status: disabled" \
    && info "KySec 已完全关闭（setstatus + 级别 custom，重启保持，.30 双重启实测）" \
    || warn "KySec 仍 enabled——手动执行 sudo setstatus disable && sudo security-switch --set custom 后重跑"
fi
info "预检通过 (DM已装=$DM_INSTALLED, QDM已装=$QDM_INSTALLED)"

# -----------------------------------------------------------------------------
# pkgs_ensure <pkg...> —— 依赖包安装：apt 优先（基线自适应）；apt 未全成返回 1，
# kit 兜底由调用方（stage 8b）逐包处理——判例 2026-11-20（.20 2503-bugfix 非 GFB
# 基线）：整批通配灌 kit debs 把 gf-pin 的 libssl-dev gf1.5 等硬灌成 iU 半配置。
# 判例 2026-11-19（.30 重灌）：镜像换血 2503-update1 后，kit 锚定 gf0.2 的 dev 包
# 与系统 gf0.4 运行库严格失配，dpkg -i 强装留下 45 个 iU 半配置包。规则：
#   a) apt 可用（99tunnel 代理在或源直连）→ 无包名 --fix-broken 复位后按名安装
#      （带包名调 apt 会让 iU 包诱导降级运行库——错误解）；
#   b) fix-broken 可能把目标包移除（当天移了 libgl-dev 全家）→ 修复后必须对账；
#   c) apt 未全成 → return 1；逐包兜底＋防降级闸＋dpkg --audit 终态门在 stage 8b。
# -----------------------------------------------------------------------------
all_installed() {
  local p
  for p in "$@"; do dpkg-query -W -f'${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || return 1; done
  return 0
}
pkgs_ensure() {
  all_installed "$@" && { info "依赖包均已安装"; return 0; }
  if [ -f /etc/apt/apt.conf.d/99tunnel ] || timeout 10 apt-get update >/dev/null 2>&1; then
    # dpkg -l 输出超管道缓冲时 grep -q 早退触发 SIGPIPE(141)×pipefail 误判（同 8h 判例）——先落变量再查
    DPKG_STATUS=$(dpkg -l 2>/dev/null) || true
    grep -q '^iU' <<<"$DPKG_STATUS" && apt-get -y --fix-broken install >/tmp/apt_fixbroken.log 2>&1 || true
    if apt-get install -y --no-install-recommends "$@" >/tmp/apt_install.log 2>&1; then
      info "已 apt 安装: $*"; return 0
    fi
    warn "apt 未全成（/tmp/apt_install.log），对账后走 kit 兜底"
    all_installed "$@" && { info "apt 安装完成（部分由 fix-broken 补齐）"; return 0; }
  fi
  return 1  # kit 兜底交调用方逐包处理（判例 2026-11-20 整批灌 iU 半配置，禁通配）
}

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
# 判例 2026-11-19：/data 可为只读位 555 且 dmdba 无法建目录——静默安装 xml 的 PATH 节点即 $DATA_PATH
# 仅当 DATA_PATH 在 DM_HOME 之外才预建：目录内时安装器自建，预建反触发「坑1 安装目录非空」拒绝
case "$DATA_PATH" in
  "$DM_HOME"|"$DM_HOME"/*) ;;
  *)
    mkdir -p "$DATA_PATH" || fail "无法创建 DATA_PATH=$DATA_PATH（检查挂载与权限）"
    chown dmdba:dinstall "$DATA_PATH"
    info "已预建 DATA_PATH=$DATA_PATH（dmdba:dinstall）"
  ;;
esac
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
<!-- 判例 2026-11-20：20260312 构建要求非空 SYSSSO_PWD 节点，缺失报"配置文件SYSSSO_PWD节点字符串不能为空"；20260324 构建无此要求 -->
<SYSSSO_PWD>$SYSSSO_PWD</SYSSSO_PWD>
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
cd /  # 坑13: 冒烟目录已删，进程残留已删 cwd，8c/8f 的 pip(os.getcwd) 报 OSError Errno 2
if echo "$OUT" | grep -q "QT_DM_SMOKE_OK"; then
  info "Qt↔DM8 全链路验证通过（含中文存取）"; echo "$OUT" | grep "ROW:"
else
  fail "Qt 冒烟失败: $(echo "$OUT" | tr '\n' ' ')"
fi

# =============================================================================
stage 8b "Python3.12 + SSL 支撑（debs 离线安装 + _ssl 修复构建）"
# =============================================================================
PY312=/usr/local/bin/python3.12
if [ "$PY_FIX_SSL" = "skip" ]; then
  warn "PY_FIX_SSL=skip，跳过 Python/SSL 阶段"
elif [ -x "$PY312" ] && "$PY312" -c "import ssl" >/dev/null 2>&1; then
  info "python3.12 的 _ssl 正常，跳过"
else
  # 1) 安装开发包：apt 优先（自动匹配当前系统基线）；apt 未全成的包走 kit 逐包兜底
  #    判例 2026-11-20（.20 2503-bugfix 非 GFB 基线）：旧「整批通配 kit debs」灌装把
  #    gf-pin 的 libssl-dev gf1.5/libsqlite3-dev gf0.2/sqlite3 gf0.2 硬灌成 iU 半配置。
  DEV_PKGS=""
  for d in "$DM_DIR"/debs/*.deb; do
    [ -f "$d" ] || continue
    pn=$(dpkg-deb -f "$d" Package 2>/dev/null) || continue
    # 包名白名单（Debian 字符集）：介质元数据不可信，拦 '-o'/'../*' 类 token 流入 apt/dpkg 参数位
    [[ "$pn" =~ ^[a-z0-9][a-z0-9+.-]+$ ]] || { warn "跳过异常包名 deb: $(basename "$d")"; continue; }
    DEV_PKGS="$DEV_PKGS $pn"
  done
  if [ -n "$DEV_PKGS" ] && ! pkgs_ensure $DEV_PKGS; then
    # kit 逐包兜底：仅装 apt 失败的包（单包 dpkg，禁整批通配）；单包失败不级联，末尾统一处理
    : >/tmp/dpkg_install.log
    KIT_FAILED=""
    KIT_RETRY=()
    for pn in $DEV_PKGS; do
      dpkg-query -W -f'${Status}' "$pn" 2>/dev/null | grep -q "install ok installed" && continue
      deb=$(ls "$DM_DIR"/debs/"$pn"_*.deb 2>/dev/null | sort -V | tail -1)  # 多版本并存取最新
      [ -n "$deb" ] || { KIT_FAILED="$KIT_FAILED $pn(缺kit deb)"; continue; }
      kitv=$(dpkg-deb -f "$deb" Version 2>/dev/null)
      [ -n "$kitv" ] || { KIT_FAILED="$KIT_FAILED $pn(kit版本不可读)"; continue; }
      installedv=$(dpkg-query -W -f'${Version}' "$pn" 2>/dev/null)
      # 防降级闸：在位版本更新则不灌 kit 旧版（判例：wget k2<在位 k2.1、icu-devtools k1<在位 k1.7）
      if [ -n "$installedv" ] && dpkg --compare-versions "$installedv" gt "$kitv"; then
        warn "防降级闸：$pn 在位 $installedv > kit $kitv，跳过 kit 兜底"
        continue
      fi
      dpkg -i "$deb" >>/tmp/dpkg_install.log 2>&1 || KIT_RETRY+=("$deb")
    done
    if [ "${#KIT_RETRY[@]}" -gt 0 ]; then
      # 首轮失配多为 kit 内依赖后置（DEV_PKGS 按文件名字典序，如 qtcreator 先于 qtcreator-data）：
      # 残包集中单次 dpkg -i——同一调用先全部解包再按依赖序配置（仅残包集合，非整批通配）
      dpkg -i "${KIT_RETRY[@]}" >>/tmp/dpkg_install.log 2>&1 \
        || { dpkg --configure -a >>/tmp/dpkg_install.log 2>&1 || true; }
      for deb in "${KIT_RETRY[@]}"; do
        pn=$(dpkg-deb -f "$deb" Package 2>/dev/null)
        dpkg-query -W -f'${Status}' "$pn" 2>/dev/null | grep -q "install ok installed" || KIT_FAILED="$KIT_FAILED $pn"
      done
    fi
    # 终态门：audit 残留与失败清单末尾统一裁决（残留清单先打屏）
    AUDIT=$(dpkg --audit 2>/dev/null)
    if [ -n "$KIT_FAILED" ] || [ -n "$AUDIT" ]; then
      [ -z "$AUDIT" ] || printf '%s\n' "$AUDIT"
      fail "kit 逐包兜底终态未收敛（失败包:${KIT_FAILED:-无}）——开 apt 隧道（bash apt-tunnel.sh on）重跑走 apt 路径（/tmp/dpkg_install.log）"
    fi
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
stage 8c "dmPython 安装与 -70089 修复（可选：PYTHON_VENV=<venv路径>）"
# =============================================================================
if [ -z "$PYTHON_VENV" ]; then
  warn "未设置 PYTHON_VENV，跳过 dmPython 阶段（启用: sudo env PYTHON_VENV=/path/to/venv bash $0 ...）"
else
  # 判例 2026-11-19：全新机器 venv 尚未存在——8b 已装 python3.12，直接代建（属主跟目录走）后继续装 dmPython
  if [ ! -x "$PYTHON_VENV/bin/python" ]; then
    [ -x "$PY312" ] || fail "venv 无效且 $PY312 未就位（先过 8b）：$PYTHON_VENV"
    sudo -n -u "$(stat -c %U "$PYTHON_VENV" 2>/dev/null || echo root)" "$PY312" -m venv "$PYTHON_VENV" \
      || fail "venv 创建失败：$PYTHON_VENV"
    info "已代建 venv（$PY312 -m venv $PYTHON_VENV）"
  fi
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
stage 8d "python3/pip3 默认化（指向 3.12）"
# =============================================================================
if [ ! -x "$PY312" ]; then
  fail "缺 $PY312（stage 8b 应已保证；PY_FIX_SSL=skip 时需先装好 Python3.12 再跑本阶段）"
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
stage 8f "venv 依赖链 numpy/pandas/statsmodels/openpyxl＋Web 七件（可选：需 PYTHON_VENV）"
# =============================================================================
WH_CUST="$DM_DIR/wheels/wheelhouse-cust"
if [ -z "$PYTHON_VENV" ]; then
  warn "未设置 PYTHON_VENV，跳过依赖链阶段"
elif [ ! -x "$PYTHON_VENV/bin/python" ]; then
  fail "PYTHON_VENV 显式传入但 venv 无效（bin/python 不可执行）：$PYTHON_VENV"
else
  # 与 8c 同款降权：kylin 属主 venv 内安装/验证以属主执行，防 root 落属主文件卡死后续 kylin pip/import
  VOWNER=$(stat -c %U "$PYTHON_VENV" 2>/dev/null || echo root)
  run_as_owner() { if [ "$VOWNER" = "root" ]; then "$@"; else sudo -n -u "$VOWNER" "$@"; fi; }
  PIN11="numpy==2.5.4 pandas==3.1.1 statsmodels==0.15.0 openpyxl==3.1.5 fastapi==0.162.5 uvicorn[standard]==0.54.0 python-can==4.6.1 websockets==17.4 pydantic==2.14.3 apscheduler==3.11.3 python-multipart==0.0.33"
  for p in numpy pandas statsmodels openpyxl; do
    ls "$WH_CUST"/"$p"-*.whl >/dev/null 2>&1 \
      || fail "$WH_CUST 缺 ${p} 顶层 wheel（按 INSTALL.md §7 制备补齐）"
  done
  # 幂等门：11 个精确 pin 全部就位才跳过（freeze 逐条全字匹配）
  if [ "$(run_as_owner "$PYTHON_VENV/bin/pip" freeze 2>/dev/null | grep -icE '^(numpy==2\.5\.4|pandas==3\.1\.1|statsmodels==0\.15\.0|openpyxl==3\.1\.5|fastapi==0\.162\.5|uvicorn==0\.54\.0|python-can==4\.6\.1|websockets==17\.4|pydantic==2\.14\.3|apscheduler==3\.11\.3|python-multipart==0\.0\.33)$')" -eq 11 ]; then
    info "11 个精确 pin 已就位，跳过安装"
  else
    run_as_owner "$PYTHON_VENV/bin/pip" install --no-index \
      --find-links "$DM_DIR/wheels" --find-links "$WH_CUST" $PIN11 \
      || fail "依赖链离线安装失败（wheel 与 venv python 版本/架构不匹配？）"
    info "11 个 pin 已安装（传递依赖 31 个 wheel 由 pip 从 wheelhouse-cust 自解析）"
  fi
  run_as_owner "$PYTHON_VENV/bin/python" -c "import numpy,pandas,statsmodels,openpyxl,fastapi,uvicorn,can,websockets,pydantic,apscheduler,multipart" >/dev/null 2>&1 \
    || fail "venv 依赖链导入验证失败"
  run_as_owner "$PYTHON_VENV/bin/pip" check >/dev/null 2>&1 || fail "pip check 报告依赖问题"
  info "venv 依赖链验证通过（import + pip check）"
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
stage 8h "ftg340 GPU 硬件渲染接线（厂商 EGL/GL 栈系统注册）"
# =============================================================================
# 206 车机（飞腾D3000M）ftg340 厂商用户态装在私有目录且默认不在链接器路径 → EGL 静默软渲染；
# 00- 前缀保证排序在 aarch64-linux-gnu.conf 之前，撞名 libEGL/libGL 时厂商栈胜出（2026-11-18 实测定稿，三层开机自恢复）
VENDOR_GL_DIR=/usr/lib/aarch64-linux-gnu/d3000m
GPU_ST="软渲染（stage 8h）"
if [ -d "$VENDOR_GL_DIR" ]; then
  printf '%s\n' "$VENDOR_GL_DIR" > /etc/ld.so.conf.d/00-ftg340-d3000m.conf
  ldconfig || fail "ldconfig 失败"
  # 变量中转：ldconfig -p 输出超管道缓冲（.30 实测 ~133KB）且厂商条目排最前，管道直连 grep -m1 早退触发 SIGPIPE(141)×pipefail 误 fail
  LDCACHE=$(ldconfig -p) || fail "ldconfig -p 失败"
  EGL1=$(grep -m1 'libEGL.so.1 (libc6,AArch64)' <<<"$LDCACHE") || true
  if grep -q d3000m <<<"$EGL1"; then
    GPU_ST="ftg340 硬件渲染已接线"
    info "GPU 硬件渲染已接线：libEGL.so.1 → $VENDOR_GL_DIR"
  else
    fail "厂商 libEGL.so.1 未胜出（应排系统 Mesa 前，检查 00- 前缀排序）"
  fi
else
  warn "缺 $VENDOR_GL_DIR（ftg340 包未装？），保持软渲染"
fi

# =============================================================================
stage 9 "清理"
# =============================================================================
rm -f "$DMDBA_HOME/DMInstall.bin" "$DMDBA_HOME/auto_install.xml" "$DMDBA_HOME/dm.key.src" 2>/dev/null
info "安装器临时文件已清理"

# =============================================================================
stage 10 "完成形态终验"
# =============================================================================
# 全流程终态只读复核：任一硬项不满足即 fail（fail-fast），全部通过才打印完成 banner
systemctl is-active --quiet "DmService$INSTANCE_NAME" || fail "终验失败：DmService$INSTANCE_NAME 非 active"
# ensure-before-verify：DmAPService 由 root_installer.sh 注册，stage 1~9 未保证在运行（对齐 stage 4 对 DmService 的先启后验手法）
systemctl enable --now DmAPService >/dev/null 2>&1 || true
systemctl is-active --quiet DmAPService || fail "终验失败：DmAPService 非 active（存量机缺该 unit 时先跑 $DM_HOME/script/root/root_installer.sh 再重跑）"
info "服务终态：DmService$INSTANCE_NAME 与 DmAPService 均 active"
ss -ltn 2>/dev/null | grep -q ":$PORT_NUM " || fail "终验失败：端口 $PORT_NUM 未监听"
VRFY_INSTANCE=$(printf '%s\nexit\n' 'SELECT INSTANCE_NAME FROM V$INSTANCE;' | "$DM_DISQL" "$DSN" 2>&1)
echo "$VRFY_INSTANCE" | grep -qF -- "$INSTANCE_NAME" || fail "终验失败：V\$INSTANCE 未返回 $INSTANCE_NAME: $(echo "$VRFY_INSTANCE" | tail -2 | tr '\n' ' ')"
info "实例/端口终态：$INSTANCE_NAME @ :$PORT_NUM"
# 判例 2026-11-20：不同 key 文件可有相同到期日（dm5D01220176.key 与 dmE301208192.key 同为 2027-06-25）——到期日不能证明 key 已更换，必须 md5 比对
[ -f "$DM_HOME/bin/dm.key" ] || fail "终验失败：缺 $DM_HOME/bin/dm.key"
[ "$(md5sum "$DM_HOME/bin/dm.key" | awk '{print $1}')" = "$(md5sum "$KEY" | awk '{print $1}')" ] \
  || fail "终验失败：dm.key 与介质 $KEY 的 md5 不一致（在位 key 非本次介质 key；换 key 手工路径: cp \"$KEY\" \"$DM_HOME/bin/dm.key\" 后 systemctl restart \"DmService$INSTANCE_NAME\" 再重跑）"
info "dm.key 终态：与介质 md5 一致"
VRFY_EXP=$(printf '%s\nexit\n' 'SELECT EXPIRED_DATE FROM V$LICENSE;' | "$DM_DISQL" "$DSN" 2>&1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
[ -n "$VRFY_EXP" ] || fail "终验失败：V\$LICENSE 的 EXPIRED_DATE 为空"
info "License 终态：到期 $VRFY_EXP"
[ -f "$QT_HOME/plugins/sqldrivers/libqsqldm.so" ] || fail "终验失败：缺 $QT_HOME/plugins/sqldrivers/libqsqldm.so"
if ldd "$QT_HOME/plugins/sqldrivers/libqsqldm.so" 2>/dev/null | grep -q "not found"; then
  fail "终验失败：libqsqldm.so 存在未解析依赖"
fi
info "QDM 驱动终态：在位且依赖全解析"
# PHMAPP 属 206 完成形态必备（stage 8g 无条件规范阶段；2026-11-20 用户确认）
VRFY_PHM=$(printf '%s\nexit\n' "SELECT USERNAME FROM DBA_USERS WHERE USERNAME = UPPER('phmapp');" | "$DM_DISQL" "$DSN" 2>&1)
echo "$VRFY_PHM" | grep -qF "PHMAPP" || fail "终验失败：数据库用户 PHMAPP 不存在: $(echo "$VRFY_PHM" | tail -2 | tr '\n' ' ')"
[ -f /home/kylin/.config/phm/dm.ini ] || fail "终验失败：缺 /home/kylin/.config/phm/dm.ini"
[ -f /etc/systemd/system/phm-app.service ] || fail "终验失败：缺 /etc/systemd/system/phm-app.service"
info "PHM 业务面终态：PHMAPP + dm.ini + phm-app.service 均就位"
# 判例 2026-11-19：dpkg 半配置 iU 残留
DPKG_AUDIT=$(dpkg --audit 2>/dev/null)
[ -z "$DPKG_AUDIT" ] || fail "终验失败：dpkg --audit 有残留（半配置包）: $(echo "$DPKG_AUDIT" | head -5 | tr '\n' ' ')"
info "dpkg --audit 干净"
if [ -n "$PYTHON_VENV" ]; then
  # 复用 8c 干净环境手法，以属主身份真连一次；密码经环境变量传递（免疫单引号密码，不落 /proc cmdline）
  runuser -u "$(stat -c %U "$PYTHON_VENV" 2>/dev/null || echo root)" -- \
    env -i PATH=/usr/bin:/bin DM_VRFY_PWD="$SYSDBA_PWD" "$PYTHON_VENV/bin/python" -c "
import os, dmPython
c = dmPython.connect(user='SYSDBA', password=os.environ['DM_VRFY_PWD'], server='127.0.0.1', port=$PORT_NUM)
print('PY_DM_VRFY_OK')
c.close()" 2>/dev/null | grep -q "PY_DM_VRFY_OK" \
    || fail "终验失败：dmPython 属主真连失败（venv=$PYTHON_VENV）"
  info "dmPython 终态：属主干净环境真连通过"
fi
info "完成形态终验全部通过"

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
echo "GPU    : $GPU_ST"
echo "PHM    : PHMAPP 账号就绪；dm.ini $([ -f /home/kylin/.config/phm/dm.ini ] && echo '已写' || echo '未写')；phm-app.service 落位未启用"
echo "License: 到期 ${EXPIRE:-见 $DM_HOME/bin/dm.key}"
echo "注意   : CHARSET($DM_CHARSET)/CASE_SENSITIVE($DM_CASE_SENSITIVE) 建库后不可改；空库期可重建"
