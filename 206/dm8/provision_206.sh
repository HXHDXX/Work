#!/usr/bin/env bash
# =============================================================================
# provision_206.sh ── 206 车机整机总装入口（飞腾 ARM64 / 麒麟 V10 / 离线内网）
#
# 用法（root）:
#   sudo bash provision_206.sh             # 无参：从 P0 自动推进到断点（FAIL 或待重启）
#   sudo bash provision_206.sh P3          # 只跑指定阶段（P0~P6，亦接受 0~6）
#   sudo bash provision_206.sh --reboot    # P2 装完内核后直接重启（缺省停在提示等人工确认）
#
# 断点续跑: 全阶段幂等（已满足即 [OK] 跳过、fail 即停），修复/重启后无参重跑自动越过关卡；
#   P2 内核装完须重启一次，重启后重跑自动过 P3（判例与定型表见 INSTALL.md）。
# 判例来源: 2026-11-20 .20 全新镜像（2503-bugfix 基线）实装实录；KySec/时钟/g++/apt 隧道
#   ＝2026-11-19 .30 重灌判例；ftg340 泛配误装 1.3.0 判例 → 本脚本严格按名取件。
# 透传: SYSDBA_PWD/PHMAPP_PWD 等环境变量原样传给两 kit（缺省同 kit 头注）；PYTHON_VENV 缺省 /home/kylin/venvs/phm。
# 阶段: P0 预检(KySec/时钟/g++) → P1 五层电源防护 → P2 内核/GPU 定型栈 → P3 五条验证
#   → P4 双 kit 部署(qt5.14.2-env-deploy + 本目录) → P5 PyCharm(未摆渡即跳过) → P6 总验
# =============================================================================
set -uo pipefail

C_G="\033[32m"; C_R="\033[31m"; C_Y="\033[33m"; C_0="\033[0m"
info()  { printf "${C_G}[OK]${C_0}  %s\n" "$*"; }
warn()  { printf "${C_Y}[WARN]${C_0} %s\n" "$*"; }
fail()  { printf "${C_R}[FAIL]${C_0} %s\n" "$*"; exit 1; }
stage() { printf "\n${C_G}========== [阶段%s] %s ==========${C_0}\n" "$1" "$2"; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
KREL=5.4.18-172-generic
KVER=5.4.18-172.166
FTG_VER=1.1.10-kylin43
FTG_DEB=ftg340_1.1.10-kylin43_arm64.deb
FTG_SRCVER=B41991B541BA938DD36A5E2
# 严格按名取件（判例：ftg340*.deb 泛配曾连 1.3.0 一起装入）——名录与 debs/SHA256SUMS.txt 对齐
KERN_DEBS="linux-image-5.4.18-172-generic_5.4.18-172.166_arm64.deb linux-modules-5.4.18-172-generic_5.4.18-172.166_arm64.deb linux-modules-extra-5.4.18-172-generic_5.4.18-172.166_arm64.deb linux-headers-5.4.18-172_5.4.18-172.166_all.deb linux-headers-5.4.18-172-generic_5.4.18-172.166_arm64.deb"
KERN_PKGS="linux-image-5.4.18-172-generic linux-modules-5.4.18-172-generic linux-modules-extra-5.4.18-172-generic linux-headers-5.4.18-172 linux-headers-5.4.18-172-generic"

STAGE_SEL=""; REBOOT=0
for a in "$@"; do
  case "$a" in
    --reboot) REBOOT=1 ;;
    [Pp][0-6]) STAGE_SEL="P${a#[Pp]}" ;;
    [0-6]) STAGE_SEL="P$a" ;;
    *) fail "未知参数: $a（用法见文件头注释）" ;;
  esac
done
want() { [ -z "$STAGE_SEL" ] || [ "$STAGE_SEL" = "$1" ]; }

kern_pkgs_ok() {
  local p
  for p in $KERN_PKGS; do
    dpkg-query -W -f'${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || return 1
  done
  return 0
}
ftg_ok() { [ "$(dpkg-query -W -f'${Version}' ftg340 2>/dev/null)" = "$FTG_VER" ]; }
# P3/P6 共用五条验证（定型表见 INSTALL.md「GPU 驱动栈定型记录」，2026-11-20 .30 全谱实测）
verify_kernel_gpu() {
  [ "$(uname -r)" = "$KREL" ] || { echo "uname -r=$(uname -r)（应 $KREL）"; return 1; }
  ftg_ok || { echo "ftg340 版本非 $FTG_VER（dpkg: $(dpkg-query -W -f'${Version}' ftg340 2>/dev/null)）"; return 1; }
  [ "$(modinfo -F srcversion ftg340 2>/dev/null)" = "$FTG_SRCVER" ] || { echo "modinfo ftg340 srcversion 非 $FTG_SRCVER（ko 非 1.1.7）"; return 1; }
  ip link 2>/dev/null | grep -q ' can0:' && ip link 2>/dev/null | grep -q ' can1:' || { echo "ip link 缺 can0/can1"; return 1; }
  kern_pkgs_ok || { echo "五内核包有缺"; return 1; }
}

if want P0; then
stage 0 "预检（KySec / 时钟 / g++）"
[ "$(id -u)" -eq 0 ] || fail "请用 root（sudo）运行本脚本"
# KySec enabled 时拦的就是脚本执行本身（RC=126 判例 2026-11-19）——总装入口不自救，必须先内联关掉
if command -v getstatus >/dev/null 2>&1 && getstatus 2>/dev/null | grep -q "^KySec status: enabled"; then
  fail "KySec enabled（将拦截脚本执行）。请先在 ssh 会话里内联执行下面这条（勿放进任何脚本）:
  sudo setstatus disable && sudo security-switch --set custom --list \"\"
（两条缺一不可：裸 --set custom 报参数错误且重启复活——2026-11-20 .30 重启实测）"
fi
info "KySec 非 enabled"
# 重灌机出厂时钟常停 2000-01-01（CMOS 空电），license 校验必失败（判例 2026-11-16/19）
[ "$(date +%Y)" -ge 2026 ] || warn "系统时钟年份 $(date +%Y) 疑似错误：先 sudo date -s 校时再重跑"
hwclock --systohc 2>/dev/null && info "时钟已写入 RTC（hwclock --systohc）" || warn "hwclock --systohc 失败"
# g++：2503 新镜像不带（判例 2026-11-19），QDM 编译/冒烟必需——apt 隧道可达即装
if command -v g++ >/dev/null 2>&1; then
  info "g++ 已在位: $(command -v g++)"
elif (exec 3<>/dev/tcp/127.0.0.1/3142) 2>/dev/null; then
  [ -f /etc/apt/apt.conf.d/99tunnel ] || bash "$SCRIPT_DIR/apt-tunnel.sh" on || fail "apt 隧道自验失败（apt-tunnel.sh on）"
  apt-get install -y --no-install-recommends g++ >/tmp/apt_gpp.log 2>&1 && command -v g++ >/dev/null 2>&1 \
    && info "g++ 已经 apt 隧道安装" \
    || fail "apt 安装 g++ 失败（/tmp/apt_gpp.log）。隧道两步: 工作站侧 ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>；设备侧 sudo bash $SCRIPT_DIR/apt-tunnel.sh on"
else
  fail "缺 g++ 且 apt 隧道未开（127.0.0.1:3142 不通）。两步处置:
  工作站侧（保持会话开着）: ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>
  设备侧                  : sudo bash $SCRIPT_DIR/apt-tunnel.sh on
然后重跑本脚本"
fi
fi

if want P1; then
stage 1 "五层电源防护（高性能不休眠，2026-11-20 .20 实录）"
# 层1 拆 kylin-process-manager：idle 节能曾掐断系统盘 SATA 链路致全系统 IO 冻死（事故链见 INSTALL.md）
pkill -9 -f 'kylin-proces[s]-manager' 2>/dev/null || true   # [s] 正则防 pkill 匹配自身（坑10）
KPM_AUTO=/etc/xdg/autostart/kylin-process-manager.desktop
[ -f "$KPM_AUTO" ] && mv "$KPM_AUTO" "$KPM_AUTO.disabled"
find /usr -name 'kylin-process-manager*' -type f 2>/dev/null | while read -r b; do chmod -x "$b"; done
pgrep -f 'kylin-proces[s]-manager' >/dev/null 2>&1 \
  && fail "kylin-process-manager 仍在运行" || info "层1 kpm 已拆（进程清/自启禁/二进制去执行位）"
# 层2 systemd 睡眠四 target mask（复核在位，幂等）
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 \
  && info "层2 睡眠四 target 已 mask" || fail "sleep target mask 失败"
# 层3+4 CPU performance + SATA max_performance（kit 同目录 service 副本）
if ! cmp -s "$SCRIPT_DIR/car-machine-perf.service" /etc/systemd/system/car-machine-perf.service 2>/dev/null; then
  cp "$SCRIPT_DIR/car-machine-perf.service" /etc/systemd/system/ && systemctl daemon-reload
fi
systemctl enable --now car-machine-perf.service >/dev/null 2>&1 \
  && systemctl is-enabled --quiet car-machine-perf.service && systemctl is-active --quiet car-machine-perf.service \
  && info "层3+4 car-machine-perf.service enabled+active" || fail "car-machine-perf.service 未 enable/active"
# 层5 UKUI 会话不锁屏不关屏（kylin 用户；dconf 策略锁防回写由 P4 qt kit stage5 加固）
if id kylin >/dev/null 2>&1; then
  runuser -u kylin -- dbus-launch gsettings set org.ukui.power-manager sleep-display-ac 0 2>/dev/null \
    && runuser -u kylin -- dbus-launch gsettings set org.ukui.screensaver idle-activation-enabled false 2>/dev/null \
    && info "层5 UKUI sleep-display-ac=0 / idle-activation-enabled=false（kylin）" \
    || warn "gsettings 写入失败（无 dbus 会话？P4 qt kit 的 dconf 策略锁会兜底）"
else
  warn "缺 kylin 用户，层5 gsettings 跳过"
fi
fi

if want P2; then
stage 2 "内核/GPU 定型栈（$KVER 五件 + ftg340 $FTG_VER）"
if [ "$(uname -r)" = "$KREL" ] && ftg_ok; then
  info "内核 $KREL × ftg340 $FTG_VER 已在位，跳过安装"
else
  TODO=""
  if [ "$(uname -r)" != "$KREL" ] && ! kern_pkgs_ok; then
    for d in $KERN_DEBS; do
      [ -f "$SCRIPT_DIR/debs/$d" ] || fail "kit debs/ 缺件: $d（介质制备见 INSTALL.md「GPU 驱动栈定型记录」）"
      TODO="$TODO $SCRIPT_DIR/debs/$d"
    done
  fi
  if ! ftg_ok; then
    [ -f "$SCRIPT_DIR/debs/$FTG_DEB" ] || fail "kit debs/ 缺件: $FTG_DEB"
    TODO="$TODO $SCRIPT_DIR/debs/$FTG_DEB"
  fi
  if [ -n "$TODO" ]; then
    dpkg -i $TODO >/tmp/dpkg_kernel.log 2>&1 || { tail -5 /tmp/dpkg_kernel.log; fail "dpkg 安装失败（/tmp/dpkg_kernel.log）"; }
    info "已安装: $(for f in $TODO; do basename "$f"; done | tr '\n' ' ')"
  fi
fi
if [ "$(uname -r)" != "$KREL" ]; then
  if [ "$REBOOT" -eq 1 ]; then
    info "内核已装，--reboot 确认 → 重启（重启后无参重跑本脚本自动续 P3 起）"
    sync; systemctl reboot; exit 0
  fi
  fail "内核 $KVER 已装须重启生效: 手动 reboot，或 sudo bash $0 --reboot；重启后无参重跑自动续跑"
fi
fi

if want P3; then
stage 3 "五条验证（内核/GPU/CAN）"
if MSG=$(verify_kernel_gpu); then
  info "五条全过: uname=$KREL / ftg340=$FTG_VER / srcversion=$FTG_SRCVER / can0+can1 / 五内核包在位"
else
  fail "验证未过: $MSG"
fi
fi

if want P4; then
stage 4 "双 kit 部署（qt5.14.2-env-deploy + dm8_qt）"
QT_KIT="$SCRIPT_DIR/../qt5.14.2-env-deploy"
[ -f "$QT_KIT/install_qt_env.sh" ] || fail "未找到 $QT_KIT/install_qt_env.sh（kit 结构不符）"
[ -f "$SCRIPT_DIR/install_dm8_qt.sh" ] || fail "未找到 $SCRIPT_DIR/install_dm8_qt.sh（kit 结构不符）"
export PYTHON_VENV="${PYTHON_VENV:-/home/kylin/venvs/phm}"
bash "$QT_KIT/install_qt_env.sh" || fail "install_qt_env.sh 失败——单跑定位: sudo bash $QT_KIT/install_qt_env.sh"
info "Qt 环境 kit 完成"
bash "$SCRIPT_DIR/install_dm8_qt.sh" || fail "install_dm8_qt.sh 失败——单跑定位: sudo env PYTHON_VENV=$PYTHON_VENV bash $SCRIPT_DIR/install_dm8_qt.sh"
info "DM8+Qt kit 完成（两 kit 各自完成形态终验已过）"
fi

if want P5; then
stage 5 "PyCharm 2025.3（可选件，未摆渡即跳过）"
PY_TGZ="$SCRIPT_DIR/pycharm-2025.3-aarch64.tar.gz"
if [ -e /opt/pycharm ]; then
  info "/opt/pycharm 已在位，跳过"
elif [ ! -f "$PY_TGZ" ]; then
  warn "未摆渡 $(basename "$PY_TGZ")，跳过 PyCharm（无 IDE 形态合法；补装=摆渡后重跑本阶段）"
else
  tar -xzf "$PY_TGZ" -C /opt || fail "解包失败（磁盘空间/tar 完整性）"
  [ -x /opt/pycharm-2025.3/bin/pycharm.sh ] || fail "解包后未见 /opt/pycharm-2025.3/bin/pycharm.sh（tarball 结构不符）"
  ln -sfn /opt/pycharm-2025.3 /opt/pycharm
  ln -sf /opt/pycharm/bin/pycharm.sh /usr/local/bin/pycharm
  cat > /usr/share/applications/pycharm.desktop <<EOF
[Desktop Entry]
Type=Application
Name=PyCharm
Exec=/opt/pycharm/bin/pycharm.sh %f
Icon=/opt/pycharm/bin/pycharm.svg
StartupWMClass=jetbrains-pycharm
Terminal=false
Categories=Development;IDE;
EOF
  file /opt/pycharm/jbr/bin/java 2>/dev/null | grep -q aarch64 \
    && info "PyCharm 已落位（JBR aarch64 验讫）" || warn "PyCharm 已落位（JBR 架构待复核: file /opt/pycharm/jbr/bin/java）"
fi
fi

if want P6; then
stage 6 "总验（内核/GPU 五条 + 双 kit 终态 + PHMAPP + PyCharm）"
if MSG=$(verify_kernel_gpu); then info "P3 五条复核通过"; else fail "总验失败（内核/GPU）: $MSG"; fi
systemctl is-active --quiet DmServiceDMSERVER && systemctl is-active --quiet DmAPService \
  && info "DM8 双服务 active（DmServiceDMSERVER/DmAPService）" || fail "总验失败：DM8 双服务非 active"
ss -ltn 2>/dev/null | grep -q ":5236 " && info "端口 5236 监听" || fail "总验失败：5236 未监听"
[ "$(/opt/Qt5.14.2/bin/qmake -v 2>/dev/null | grep -oE '5\.14\.2' | head -1)" = "5.14.2" ] \
  && info "qmake 5.14.2" || fail "总验失败：qmake 非 5.14.2"
command -v qtcreator >/dev/null 2>&1 \
  && info "qtcreator $(dpkg-query -W -f'${Version}' qtcreator 2>/dev/null)" \
  || warn "软项：qtcreator 未装（无 IDE 形态合法）"
DM_HOME=/opt/dm8; [ -x "$DM_HOME/bin/disql" ] || DM_HOME=/dm8
DSN="SYSDBA/\"${SYSDBA_PWD:-PHMadmin1}\"@localhost:5236"
printf '%s\nexit\n' "SELECT USERNAME FROM DBA_USERS WHERE USERNAME = UPPER('phmapp');" \
  | "$DM_HOME/bin/disql" "$DSN" 2>&1 | grep -q PHMAPP \
  && info "PHMAPP 账号在位" || fail "总验失败：PHMAPP 不存在（disql 无法确认）"
[ -x /opt/pycharm/bin/pycharm.sh ] && info "PyCharm 在位" || warn "软项：PyCharm 未装（无 IDE 形态合法）"
echo
printf "${C_G}================= 206 整机总装完成 =================${C_0}\n"
fi
