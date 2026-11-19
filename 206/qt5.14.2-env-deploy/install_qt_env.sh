#!/usr/bin/env bash
# =============================================================================
# Qt 5.14.2 开发环境 一键部署/恢复脚本（飞腾 ARM64 / 麒麟 V10 SP1 / 离线内网）
#
# 备份包内容（与本脚本同目录）:
#   qt_backup.tar.gz  ─ /opt/Qt5.14.2（含 QDM 达梦驱动 + fcitx 输入法插件,预编译）
#                        /home/kylin/qt5 模块源码树(10模块)
#                        /home/kylin/fcitx-qt5 插件源码
#                        /etc/profile.d/qt5142.sh + QtCreator 版本注册(qtversion.xml)
#   debs/              ─ 89 个离线 deb（QtCreator 4.11.0 + 编译依赖 + gdb + cmake/ECM）
#
# 用法:
#   sudo bash install_qt_env.sh [备份包目录]     # 缺省=脚本所在目录
#
# 环境变量: KIT_DIR 同上;  FORCE_UNTAR=1 强制重新解包
# 幂等: Qt 已就位跳过解包; deb 已装跳过安装。详细说明见 README-QT-ENV.md
# =============================================================================
set -uo pipefail

C_G="\033[32m"; C_R="\033[31m"; C_Y="\033[33m"; C_0="\033[0m"
info()  { printf "${C_G}[OK]${C_0}  %s\n" "$*"; }
warn()  { printf "${C_Y}[WARN]${C_0} %s\n" "$*"; }
fail()  { printf "${C_R}[FAIL]${C_0} %s\n" "$*"; exit 1; }
stage() { printf "\n${C_G}========== [阶段%s] %s ==========${C_0}\n" "$1" "$2"; }

QT_HOME=/opt/Qt5.14.2

# =============================================================================
stage 0 "预检"
# =============================================================================
[ "$(id -u)" -eq 0 ] || fail "请用 root（sudo）运行"
ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] || warn "当前架构 $ARCH，备份包为 arm64 构建，非 aarch64 将不可用"
KIT_DIR="${1:-${KIT_DIR:-}}"
[ -z "$KIT_DIR" ] && KIT_DIR=$(dirname "$0")
[ -d "$KIT_DIR" ] || fail "备份包目录不存在: $KIT_DIR"
KIT_DIR=$(cd "$KIT_DIR" && pwd)
info "备份包目录: $KIT_DIR"
[ -f "$KIT_DIR/qt_backup.tar.gz" ] || fail "缺少 qt_backup.tar.gz"
[ -d "$KIT_DIR/debs" ] && DEB_COUNT=$(ls "$KIT_DIR"/debs/*.deb 2>/dev/null | wc -l) || DEB_COUNT=0
[ "$DEB_COUNT" -gt 0 ] || warn "debs/ 目录为空，跳过离线 deb 安装（需设备自行保证 qtcreator/依赖已装）"
dpkg -s qtcreator >/dev/null 2>&1 && QTC_OK=1 || QTC_OK=0
# --- KySec（判例 2026-11-19：2503-update1 镜像默认 enabled，拦截 kit 脚本执行 RC=126）---
if command -v getstatus >/dev/null 2>&1 && getstatus 2>/dev/null | grep -q "^KySec status: enabled"; then
  setstatus disable >/dev/null 2>&1 && info "KySec 已运行时关闭（重启失效）" \
    || warn "KySec 关闭失败——遇 KYSEC 权限错误请手动 sudo setstatus disable 后重跑"
fi

# =============================================================================
stage 1 "离线安装 deb（QtCreator 4.11.0 / 编译依赖 / gdb / cmake）"
# =============================================================================
if [ "$QTC_OK" -eq 1 ] && [ "$DEB_COUNT" -eq 0 ]; then
  info "qtcreator 已安装且无离线包，跳过"
elif [ "$DEB_COUNT" -gt 0 ]; then
  # 判例 2026-11-19（基线漂移）：dry-run 预检，强装会留 iU 半配置包且本阶段曾静默放行
  if ! dpkg --dry-run -i "$KIT_DIR"/debs/*.deb >/tmp/qt_dryrun.log 2>&1; then
    grep -Ei "dependency|依赖|conflict|architecture" /tmp/qt_dryrun.log | head -5
    fail "kit debs 与当前系统基线疑似失配（/tmp/qt_dryrun.log）——开 apt 隧道（206/dm8/apt-tunnel.sh on）改走 apt，或按新基线换血 kit debs"
  fi
  echo "dpkg 安装 $DEB_COUNT 个 deb ..."
  if ! dpkg -i "$KIT_DIR"/debs/*.deb >/tmp/qt_debs.log 2>&1; then
    warn "dpkg 返回非0，检查 /tmp/qt_debs.log（已装新版属正常，致命错误才需处理）"
    grep -E "^dpkg:.*(错误|error)" /tmp/qt_debs.log | head -5
  fi
  dpkg -s qtcreator >/dev/null 2>&1 || fail "qtcreator 安装失败，见 /tmp/qt_debs.log"
  # dpkg -l 输出超管道缓冲时 grep -q 早退触发 SIGPIPE(141)×pipefail 误判（同 dm8 脚本判例）——先落变量再查
  DPKG_STATUS=$(dpkg -l 2>/dev/null) || true
  if grep -q '^iU' <<<"$DPKG_STATUS"; then
    warn "残留 iU 半配置包（基线失配特征）：$(awk '/^iU/{print $2}' <<<"$DPKG_STATUS" | tr '\n' ' ')"
    fail "修复姿势（判例 2026-11-19）：先 bash 206/dm8/apt-tunnel.sh on，再无包名 apt-get -y --fix-broken install，最后对账补装（fix-broken 可能把目标包移除，必须复查）"
  fi
  info "deb 安装完成（qtcreator $(dpkg-query -W -f '${Version}' qtcreator 2>/dev/null)）"
fi

# =============================================================================
stage 2 "恢复 Qt 5.14.2 + 源码树 + 插件（预编译包解包）"
# =============================================================================
if [ -x "$QT_HOME/bin/qmake" ] && [ "${FORCE_UNTAR:-0}" != "1" ]; then
  info "$QT_HOME 已存在，跳过解包（FORCE_UNTAR=1 可强制覆盖恢复）"
else
  echo "解包中（约1~2分钟）..."
  tar xzf "$KIT_DIR/qt_backup.tar.gz" -C / || fail "解包失败（检查磁盘空间与 tar 完整性）"
  # 归档里的 profile 脚本打包时在 /tmp 下，就位
  [ -f /tmp/etc-profile-qt5142.sh ] && cp /tmp/etc-profile-qt5142.sh /etc/profile.d/qt5142.sh && rm -f /tmp/etc-profile-qt5142.sh
  # 归档内 /opt 部分为 root 属主；源码树属 kylin，目标机 kylin 的 UID 可能不同 → 统一修正
  id kylin >/dev/null 2>&1 && chown -R kylin:kylin /home/kylin/qt5 /home/kylin/fcitx-qt5 /home/kylin/.config 2>/dev/null
  [ -x "$QT_HOME/bin/qmake" ] || fail "解包后未找到 $QT_HOME/bin/qmake，备份包损坏？"
  info "Qt 5.14.2 + 源码树 + 插件已恢复"
fi

# =============================================================================
stage 3 "验证组件"
# =============================================================================
"$QT_HOME/bin/qmake -v" >/dev/null 2>&1 || { "$QT_HOME/bin/qmake" -v | tail -1 || fail "qmake 异常"; }
V=$("$QT_HOME/bin/qmake" -v | tail -1 | grep -oE "5\.14\.2") && info "qmake: $V" || fail "qmake 版本异常"
command -v qtcreator >/dev/null && info "QtCreator: $(dpkg-query -W -f '${Version}' qtcreator 2>/dev/null)"
for p in sqldrivers/libqsqldm.so platforminputcontexts/libfcitxplatforminputcontextplugin.so; do
  [ -f "$QT_HOME/plugins/$p" ] && info "插件: $p" || warn "缺插件 $p（QDM=达梦驱动 / fcitx=中文输入法）"
done
[ -f /etc/profile.d/qt5142.sh ] && info "PATH(/etc/profile.d/qt5142.sh) 就绪（新登录生效）" \
  || warn "缺少 profile.d/qt5142.sh（手工: echo 'export PATH=$QT_HOME/bin:\$PATH' > /etc/profile.d/qt5142.sh）"
[ -f /home/kylin/.config/QtProject/qtversion.xml ] && info "QtCreator 版本注册(qtversion.xml) 已就位"

# =============================================================================
stage 4 "达梦联动检查（可选）"
# =============================================================================
DM_ROOT=""
[ -x /opt/dm8/bin/dmserver ] && DM_ROOT=/opt/dm8
[ -z "$DM_ROOT" ] && [ -x /dm8/bin/dmserver ] && DM_ROOT=/dm8
if [ -n "$DM_ROOT" ]; then
  [ -f /etc/ld.so.conf.d/dm8.conf ] || printf "%s/drivers/dpi\n%s/drivers/odbc/dependencies\n" "$DM_ROOT" "$DM_ROOT" > /etc/ld.so.conf.d/dm8.conf
  ldconfig
  info "检测到达梦已安装（$DM_ROOT），DPI 库寻址已配置，QDM 驱动即可使用（QSqlDatabase::addDatabase(\"QDM\")）"
else
  warn "未检测到达梦（/opt/dm8 或 /dm8）。QDM 驱动需先部署 DM8（见 dm8 部署包 install_dm8_qt.sh）"
fi

# =============================================================================
stage 5 "防休眠/防锁屏（无人值守车机）"
# =============================================================================
# 判例 2026-11-19：桌面镜像默认自动休眠+空闲锁屏；ukui-screensaver-backend 由
# ukui-session 守护复活并在启动时回写 gsettings——dbus 私有总线/会话总线写入均会被
# 覆盖（实测 25 分钟后复现锁屏）。正解＝dconf 系统策略库+locks（管理员层强制，
# 回写被弹回，策略锁后 15 分钟复验全键稳定），辅以 systemd mask 与 logind ignore。
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 \
  && info "systemd 睡眠四 target 已 mask（含手动 suspend）" \
  || warn "sleep target mask 失败，请人工核查 systemctl status sleep.target"
grep -q "^HandleLidSwitch=ignore" /etc/systemd/logind.conf || printf \
"HandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\nIdleAction=ignore\n" \
>> /etc/systemd/logind.conf
info "logind 合盖/空闲已置 ignore（下次登录起效）"
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d/locks
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/00-screensaver <<'KV'
[org/ukui/screensaver]
idle-activation-enabled=false
lock-enabled=false
idle-lock-enabled=false
sleep-activation-enabled=false
user-switch-enabled=false
idle-delay=0
[org/ukui/session]
idle-delay=0
logout-timeout=0
[org/ukui/power-manager]
sleep-computer-ac=0
sleep-computer-battery=0
sleep-computer-ups=0
sleep-display-ac=0
sleep-display-battery=0
sleep-display-ups=0
KV
cat > /etc/dconf/db/local.d/locks/00-screensaver <<'LK'
/org/ukui/screensaver/idle-activation-enabled
/org/ukui/screensaver/lock-enabled
/org/ukui/screensaver/idle-lock-enabled
/org/ukui/screensaver/sleep-activation-enabled
/org/ukui/screensaver/user-switch-enabled
/org/ukui/screensaver/idle-delay
/org/ukui/session/idle-delay
/org/ukui/session/logout-timeout
/org/ukui/power-manager/sleep-computer-ac
/org/ukui/power-manager/sleep-computer-battery
/org/ukui/power-manager/sleep-computer-ups
/org/ukui/power-manager/sleep-display-ac
/org/ukui/power-manager/sleep-display-battery
/org/ukui/power-manager/sleep-display-ups
LK
dconf update || fail "dconf update 失败"
info "dconf 系统策略库已锁死屏保/锁屏/关屏/睡眠 14 键（backend 回写无效，重启不复发）"
if [ -f /etc/xdg/autostart/ukui-screensaver.desktop ]; then
  mv /etc/xdg/autostart/ukui-screensaver.desktop /etc/xdg/autostart/ukui-screensaver.desktop.disabled
  info "屏保后端自启已禁（ukui-session 仍会拉活，但策略锁下无害）"
fi

echo
printf "${C_G}================= Qt 环境部署完成 =================${C_0}\n"
echo "qmake    : $QT_HOME/bin/qmake（新终端生效 PATH，或 source /etc/profile）"
echo "QtCreator: qtcreator（应用菜单/终端），Kit 已预注册 Qt 5.14.2"
echo "源码树   : /home/kylin/qt5（增量补模块用，参照 README-QT-ENV.md）"
echo "中文输入 : 5.14.2 程序自动走 fcitx（已含插件）"
echo "达梦     : addDatabase(\"QDM\") + QT += sql（需 DM8 已部署）"
echo "防休眠   : 睡眠/锁屏/关屏策略级全禁（dconf locks + systemd mask；判例 2026-11-19）"
