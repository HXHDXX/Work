#!/usr/bin/env bash
# =============================================================================
# provision_206.sh ── 206 车机整机总装入口（飞腾 ARM64 / 麒麟 V10 / 离线内网）
#
# 用法（root）:
#   sudo bash provision_206.sh             # 无参：从 P0 自动推进到断点（FAIL 或待重启）
#   sudo bash provision_206.sh P3          # 只跑指定阶段（P0~P6，亦接受 0~6）
#   sudo bash provision_206.sh --reboot    # P2 装完内核/P5 完成落戳后直接重启（缺省停在提示等人工确认）
#
# 断点续跑: 全阶段幂等（已满足即 [OK] 跳过、fail 即停），修复/重启后无参重跑自动越过关卡；P2 换内核/GPU 后须重启一次；P5 落戳后须最终重启才过 P6 重启门。
# 判例来源: 2026-11-20 .20 全新镜像（2503-bugfix 基线）实装实录；KySec/时钟/g++/apt 隧道＝2026-11-19 .30 重灌判例；
#   ftg340 泛配误装 1.3.0 判例 → 本脚本严格按名取件、并校验内存中已加载版本。
# 透传: SYSDBA_PWD/PHMAPP_PWD 等环境变量原样传给两 kit（缺省同 kit 头注）；PYTHON_VENV 缺省 /home/kylin/venvs/phm。
# 阶段: P0 预检(KySec/时钟/g++) → P1 五层电源防护+音量定型 → P2 内核/GPU 定型栈 → P3 五条验证 → P4 双 kit 部署 → P5 PyCharm+落戳 → P6 重启后全量总验
# =============================================================================
set -uo pipefail

C_G="\033[32m"; C_R="\033[31m"; C_Y="\033[33m"; C_0="\033[0m"
info()  { printf "${C_G}[OK]${C_0}  %s\n" "$*"; }
warn()  { printf "${C_Y}[WARN]${C_0} %s\n" "$*"; }
fail()  { printf "${C_R}[FAIL]${C_0} %s\n" "$*"; exit 1; }
stage() { printf "\n${C_G}========== [阶段%s] %s ==========${C_0}\n" "$1" "$2"; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOG=$(mktemp /tmp/provision206.XXXXXX)   # 日志落随机名：/tmp 固定名重定向会跟随预置软链（C 册判据）
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
# 全局 root 守卫（原 P0 内检查只护无参首跑；单阶段调用同样写系统路径/落戳）
[ "$(id -u)" -eq 0 ] || fail "请用 root（sudo）运行本脚本"

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
  # 内存中已加载版本须与盘上一致：dpkg 降级只换盘上 ko，旧模块服役到重启——modinfo 只读盘上文件（B 册判据）
  LOADED=$(cat /sys/module/ftg340/srcversion 2>/dev/null)
  [ -z "$LOADED" ] || [ "$LOADED" = "$FTG_SRCVER" ] || { echo "已加载 ftg340 srcversion=$LOADED（盘上已换，须重启加载新版）"; return 1; }
  ip link 2>/dev/null | grep -q ' can0:' && ip link 2>/dev/null | grep -q ' can1:' || { echo "ip link 缺 can0/can1"; return 1; }
  kern_pkgs_ok || { echo "五内核包有缺"; return 1; }
}
# 桌面会话上下文（音量/dconf 须以会话用户经其会话总线操作，root 无 pulse/会话）——从 ukui-session 推导
ukui_sess_env() {
  SESS_PID=$(pgrep -ox ukui-session 2>/dev/null) || return 1
  SESS_USER=$(ps -o user= -p "$SESS_PID" | tr -d ' ')
  [ -n "$SESS_USER" ] || return 1
  SESS_XRD=$(tr '\0' '\n' <"/proc/$SESS_PID/environ" 2>/dev/null | sed -n 's/^XDG_RUNTIME_DIR=//p')
  [ -n "$SESS_XRD" ] || SESS_XRD="/run/user/$(id -u "$SESS_USER")"
}
as_sess()    { runuser -u "$SESS_USER" -- env XDG_RUNTIME_DIR="$SESS_XRD" "$@"; }
boot_epoch() { echo $(( $(date +%s) - $(cut -d. -f1 /proc/uptime) )); }
if want P0; then
stage 0 "预检（KySec / 时钟 / g++）"
# KySec enabled 时拦的就是脚本执行本身（RC=126 判例 2026-11-19）——总装入口不自救，必须先内联关掉
if command -v getstatus >/dev/null 2>&1 && getstatus 2>/dev/null | grep -q "^KySec status: enabled"; then
  fail "KySec enabled（将拦截脚本执行）。请先在 ssh 会话里内联执行下面这条（勿放进任何脚本）:
  sudo setstatus disable && sudo security-switch --set custom --list \"\"
（两条缺一不可：裸 --set custom 报参数错误且重启复活——2026-11-20 .30 重启实测）"
fi
# 重灌机出厂时钟常停 2000-01-01（CMOS 空电），license 校验必失败（判例 2026-11-16/19）
[ "$(date +%Y)" -ge 2026 ] || warn "系统时钟年份 $(date +%Y) 疑似错误：先 sudo date -s 校时再重跑"
hwclock --systohc 2>/dev/null && info "时钟已写入 RTC（hwclock --systohc）" || warn "hwclock --systohc 失败"
# g++：2503 新镜像不带（判例 2026-11-19），QDM 编译/冒烟必需——apt 隧道可达即装
if command -v g++ >/dev/null 2>&1; then
  info "g++ 已在位: $(command -v g++)"
elif (exec 3<>/dev/tcp/127.0.0.1/3142) 2>/dev/null; then
  [ -f /etc/apt/apt.conf.d/99tunnel ] || bash "$SCRIPT_DIR/apt-tunnel.sh" on || fail "apt 隧道自验失败（apt-tunnel.sh on）"
  apt-get install -y --no-install-recommends g++ >"$LOG" 2>&1 && command -v g++ >/dev/null 2>&1 \
    && info "g++ 已经 apt 隧道安装" \
    || fail "apt 安装 g++ 失败（$LOG）。隧道两步: 工作站侧 ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>；设备侧 sudo bash $SCRIPT_DIR/apt-tunnel.sh on"
else
  fail "缺 g++ 且 apt 隧道未开（127.0.0.1:3142 不通）。两步处置:
  工作站侧（保持会话开着）: ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>
  设备侧                  : sudo bash $SCRIPT_DIR/apt-tunnel.sh on
然后重跑本脚本"
fi
fi
if want P1; then
stage 1 "五层电源防护（高性能不休眠，2026-11-20 .20 实录）"
# 层1 拆 kylin-process-manager（kpm）：idle 节能曾掐断系统盘 SATA 链路致全系统 IO 冻死（事故链见 INSTALL.md）
# 判例：真身 /usr/bin/kylin-process-manager-daemon，重启后经 systemd 单元复活——正解 disable+mask（chmod 路径目标猜错无效且误导，已废）
# pgrep 按 comm 匹配且 comm 截断 15 字节：28 字节全名 -x 恒不中（procps 实测告警），须锚 ^kylin-process-m 前缀
systemctl disable --now kylin-process-manager-daemon.service >/dev/null 2>&1
systemctl mask kylin-process-manager-daemon.service >/dev/null 2>&1
KPM_AUTO=/etc/xdg/autostart/kylin-process-manager.desktop
[ -f "$KPM_AUTO" ] && mv "$KPM_AUTO" "$KPM_AUTO.disabled"
if ! systemctl is-active --quiet kylin-process-manager-daemon.service && ! pgrep '^kylin-process-m' >/dev/null; then
  info "层1 kpm 已拆（systemd disable+mask、进程空、autostart 辅禁）"
else
  fail "层1 kpm 未净：unit 非 inactive 或进程仍在"
fi
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
  # 任务栏隐藏（车机全屏形态）：面板常驻置顶会遮挡应用底部（判例 2026-11-21 .20/.30 对照，hidepanel=true 缩 3px 藏底边）
  # 面板自持设置无守护回写，不入 dconf 策略锁；下次登录/面板重启生效
  runuser -u kylin -- dbus-launch gsettings set org.ukui.panel.settings hidepanel true 2>/dev/null \
    && info "层5 UKUI 任务栏 hidepanel=true（kylin）" \
    || warn "hidepanel 写入失败"
  # 显示缩放 150%（判例 2026-11-21）：应用窗口高度随字体 DPI 推算，100%/125% 均不满屏，144dpi 才盖满（96×1.5）
  runuser -u kylin -- dbus-launch gsettings set org.ukui.SettingsDaemon.plugins.xsettings scaling-factor 1.5 2>/dev/null \
    && info "层5 UKUI 显示缩放 scaling-factor=1.5（kylin）" \
    || warn "scaling-factor 写入失败"
else
  warn "缺 kylin 用户，层5 gsettings 跳过"
fi
# 音量定型（2026-11-20 用户裁定：最大音量纳入校验脚本）
# 判例：kylin 构建 pactl 的 set-sink-volume 子命令不可用（list 正常、set 报"未指定有效的命令"），amixer -D pulse 为验证可行路径（.20 实机）
# 判例：双层出声链（pulse×hw），单层断言即假绿（2026-11-21）
if ukui_sess_env; then
  as_sess amixer -D pulse sset Master 100% unmute >/dev/null 2>&1
  amixer -c 0 sset Master 100% unmute >/dev/null 2>&1   # hw Master 为 Mono 量程 0-80，100% 由 amixer 换算
  VOL_P=$(as_sess amixer -D pulse sget Master 2>/dev/null); VOL_H=$(amixer -c 0 sget Master 2>/dev/null)
  printf '%s' "$VOL_P" | grep -q '\[100%\]' && printf '%s' "$VOL_P" | grep -q '\[on\]' \
    && printf '%s' "$VOL_H" | grep -q '\[100%\]' && printf '%s' "$VOL_H" | grep -q '\[on\]' \
    && info "音量定型 Master=100% unmute 双层（pulse×hw，${SESS_USER} 会话）" \
    || fail "音量定型双层回读未含 [100%]/[on]（pulse: amixer -D pulse / hw: amixer -c 0）"
else
  warn "无 ukui 桌面会话，音量定型跳过（P6 重启后会话在位时终验）"
fi
fi
if want P2; then
stage 2 "内核/GPU 定型栈（$KVER 五件 + ftg340 $FTG_VER）"
if [ "$(uname -r)" = "$KREL" ] && ftg_ok && kern_pkgs_ok; then
  info "内核 $KREL × ftg340 $FTG_VER 已在位，跳过安装"
else
  TODO=()
  if ! kern_pkgs_ok; then
    for d in $KERN_DEBS; do
      [ -f "$SCRIPT_DIR/debs/$d" ] || fail "kit debs/ 缺件: $d（介质制备见 INSTALL.md「GPU 驱动栈定型记录」）"
      TODO+=("$SCRIPT_DIR/debs/$d")
    done
  fi
  if ! ftg_ok; then
    [ -f "$SCRIPT_DIR/debs/$FTG_DEB" ] || fail "kit debs/ 缺件: $FTG_DEB"
    TODO+=("$SCRIPT_DIR/debs/$FTG_DEB")
  fi
  if [ "${#TODO[@]}" -gt 0 ]; then
    dpkg -i "${TODO[@]}" >"$LOG" 2>&1 || { tail -5 "$LOG"; fail "dpkg 安装失败（$LOG）"; }
    info "已安装: $(basename -a "${TODO[@]}" | tr '\n' ' ')"
  fi
fi
LOADED_FTG=$(cat /sys/module/ftg340/srcversion 2>/dev/null)
if [ "$(uname -r)" != "$KREL" ] || { [ -n "$LOADED_FTG" ] && [ "$LOADED_FTG" != "$FTG_SRCVER" ]; }; then
  if [ "$REBOOT" -eq 1 ]; then
    info "内核/GPU 已装，--reboot 确认 → 重启（重启后无参重跑本脚本自动续 P3 起）"
    sync; systemctl reboot; exit 0
  fi
  fail "内核/GPU 已装须重启生效（uname 或内存中 ftg340 仍旧版）: 手动 reboot，或 sudo bash $0 --reboot；重启后无参重跑自动续跑"
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
# kit 路径可用 QT_ENV_KIT 覆盖（sudo 会清环境，须 sudo env 显式传）: sudo env QT_ENV_KIT=/home/kylin/kit-206/qt-env bash provision_206.sh
QT_KIT="${QT_ENV_KIT:-$SCRIPT_DIR/../qt5.14.2-env-deploy}"
[ -f "$QT_KIT/install_qt_env.sh" ] || fail "未找到 $QT_KIT/install_qt_env.sh——按仓库布局摆放目录（$SCRIPT_DIR/../qt5.14.2-env-deploy），或设 QT_ENV_KIT 指向 kit"
[ -f "$SCRIPT_DIR/install_dm8_qt.sh" ] || fail "未找到 $SCRIPT_DIR/install_dm8_qt.sh（kit 结构不符）"
export PYTHON_VENV="${PYTHON_VENV:-/home/kylin/venvs/phm}"
bash "$QT_KIT/install_qt_env.sh" || fail "install_qt_env.sh 失败——单跑定位: sudo bash $QT_KIT/install_qt_env.sh"
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
# 安装完成落戳（P6 重启门依据）：内容=纪元秒+boot_id 两行。boot_id 换代=真实重启铁证——
# 纯纪元比较会被「CMOS 空电错时钟（判例：出厂停 2000-01-01）+ date -s 校时」假通过，反向（重启后时钟回退）则假拦
STAMP=/var/lib/provision-206.stamp
CUR_BID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
STAMP_BID=$(sed -n '2p' "$STAMP" 2>/dev/null)
if [ ! -f "$STAMP" ] || [ -z "$STAMP_BID" ] || [ "$STAMP_BID" = "$CUR_BID" ]; then
  { date +%s; echo "$CUR_BID"; } >"$STAMP" || fail "戳记写入失败: $STAMP（root 权限/磁盘？）"
  if [ "$REBOOT" -eq 1 ]; then
    info "安装完成（戳记已落）——--reboot → 立即重启；重启后无参重跑或 $0 P6 即总验"
    sync; systemctl reboot || fail "reboot 发起失败"; exit 0
  fi
  info "安装完成，须最终重启后跑 P6 总验（重启后 sudo bash $0 P6，或无参重跑）"
  exit 0
fi
fi
if want P6; then
stage 6 "重启后总验（重启门 → 全量断言，全绿才 PROVISION-ALL-GREEN）"
# 重启门（deterministic，2026-11-20 用户裁定：重启前不算验完——当日判例：改完即验全绿，
# 重启后 kpm 经 systemd 单元复活、governor/SATA 因 sysfs 晚绑定假绿、会话守护内存旧配置致屏保仍触发）
# 判定=boot_id 换代（同 boot 换不了 id）；纪元仅作人读信息（错时钟机不可作硬判据）
STAMP=/var/lib/provision-206.stamp
[ -f "$STAMP" ] || fail "未找到 $STAMP——先无参跑完 P0~P5 落戳"
STAMP_T=$(sed -n '1p' "$STAMP"); STAMP_BID=$(sed -n '2p' "$STAMP")
CUR_BID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
[ -n "$STAMP_BID" ] && [ -n "$CUR_BID" ] || fail "$STAMP 内容损坏（须两行：纪元+boot_id）——删除后重跑 P5 落戳"
[ "$CUR_BID" != "$STAMP_BID" ] || fail "安装后未重启（boot_id 仍为落戳时 boot；boot 纪元 $(boot_epoch)，戳记 $STAMP_T）——先 reboot 再跑 P6"
info "重启门通过（boot_id 已换代；boot 纪元 $(boot_epoch)，戳记 $STAMP_T）"
# 全量断言：逐项 [OK]/[FAIL]，全绿才打终态行；任一 FAIL 即 fail（已过重启门，属真实缺口）
P6_FAILS=0
chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then info "$d"; else printf "${C_R}[FAIL]${C_0} %s\n" "$d"; P6_FAILS=$((P6_FAILS+1)); fi; }
DM_HOME=/opt/dm8; [ -x "$DM_HOME/bin/disql" ] || DM_HOME=/dm8
[ -x "$DM_HOME/bin/disql" ] || fail "总验失败：未找到 disql（/opt/dm8 与 /dm8 均无，非标路径？）"
DSN="SYSDBA/\"${SYSDBA_PWD:-PHMadmin1}\"@localhost:5236"
QDM_SO=/opt/Qt5.14.2/plugins/sqldrivers/libqsqldm.so
p6_sql()      { printf '%s\nexit\n' "$1" | "$DM_HOME/bin/disql" "$DSN" 2>&1; }
p6_5236()     { ss -ltn 2>/dev/null | grep ':5236 '; }
p6_instance() { p6_sql 'SELECT INSTANCE_NAME FROM V$INSTANCE;' | grep DMSERVER; }
p6_license()  { p6_sql 'SELECT EXPIRED_DATE FROM V$LICENSE;' | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}'; }
p6_key()      { [ -f "$DM_HOME/bin/dm.key" ] && [ -f "$SCRIPT_DIR/dm5D01220176.key" ] \
  && [ "$(md5sum "$DM_HOME/bin/dm.key" 2>/dev/null | cut -d' ' -f1)" = "$(md5sum "$SCRIPT_DIR/dm5D01220176.key" 2>/dev/null | cut -d' ' -f1)" ]; }
p6_qdm_ldd()  { ! ldd "$QDM_SO" 2>/dev/null | grep 'not found'; }
p6_phmapp()   { p6_sql "SELECT USERNAME FROM DBA_USERS WHERE USERNAME = UPPER('phmapp');" | grep PHMAPP; }
p6_qmake()    { /opt/Qt5.14.2/bin/qmake -v 2>/dev/null | grep '5\.14\.2'; }
p6_kpm_unit() { ! systemctl is-active --quiet kylin-process-manager-daemon.service; }
p6_kpm_proc() { ! pgrep '^kylin-process-m'; }
p6_gov()      { local f; for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do grep -qx performance "$f" || return 1; done; }
p6_sata()     { local f; for f in /sys/class/scsi_host/host*/link_power_management_policy; do grep -qx max_performance "$f" || return 1; done; }
p6_masked()   { local t; for t in sleep suspend hibernate hybrid-sleep; do [ "$(systemctl is-enabled "$t.target" 2>/dev/null)" = "masked" ] || return 1; done; }
p6_dconf()    {  # 会话内生效值（会话守护内存配置才是真状态，非仅 dconf 库文件值）
  ukui_sess_env || return 1
  as_sess gsettings get org.ukui.screensaver idle-activation-enabled 2>/dev/null | grep -x false || return 1
  as_sess gsettings get org.ukui.screensaver idle-delay 2>/dev/null | grep -x -e 0 -e 'uint32 0' || return 1
  as_sess gsettings get org.ukui.power-manager sleep-display-ac 2>/dev/null | grep -x -e 0 -e 'uint32 0'
}
p6_panel()    { ukui_sess_env || return 1
  as_sess gsettings get org.ukui.panel.settings hidepanel 2>/dev/null | grep -x true; }
p6_scale()    { ukui_sess_env || return 1
  as_sess gsettings get org.ukui.SettingsDaemon.plugins.xsettings scaling-factor 2>/dev/null | grep -x 1.5; }
p6_vol()      { local o; ukui_sess_env || return 1; o=$(as_sess amixer -D pulse sget Master 2>/dev/null) || return 1
  printf '%s' "$o" | grep '\[100%\]' && printf '%s' "$o" | grep '\[on\]'; }
p6_vol_hw()   { local o; o=$(amixer -c 0 sget Master 2>/dev/null) || return 1
  printf '%s' "$o" | grep '\[100%\]' && printf '%s' "$o" | grep '\[on\]'; }
p6_audit()    { [ -z "$(dpkg --audit 2>&1)" ]; }
p6_py()       { readlink /usr/local/bin/python3 2>/dev/null | grep 'python3\.12$'; }

chk 'DM8 DmServiceDMSERVER active'   systemctl is-active --quiet DmServiceDMSERVER
chk 'DM8 DmAPService active'         systemctl is-active --quiet DmAPService
chk 'DM8 端口 5236 监听'             p6_5236
chk 'DM8 V$INSTANCE=DMSERVER'        p6_instance
chk 'DM8 dm.key=kit dm5D01220176.key' p6_key
chk 'DM8 License 到期非空'           p6_license
chk 'QDM libqsqldm.so 在位'          test -f "$QDM_SO"
chk 'QDM ldd 无 not found'           p6_qdm_ldd
chk 'PHMAPP 账号在位'                p6_phmapp
chk 'phm dm.ini 在位'                test -f /home/kylin/.config/phm/dm.ini
chk 'phm-app.service 在位'           test -f /etc/systemd/system/phm-app.service
chk 'qmake -v 含 Qt 5.14.2'          p6_qmake
chk 'qtcreator 已装（dpkg -s）'      dpkg -s qtcreator
chk '/opt/pycharm 在位'              test -e /opt/pycharm
chk '/usr/local/bin/pycharm 软链'    test -L /usr/local/bin/pycharm
chk '内核/GPU 五条'                  verify_kernel_gpu
chk '电源 kpm 单元 inactive'         p6_kpm_unit
chk '电源 kpm 进程空'                p6_kpm_proc
chk '电源 CPU 逐核 performance'      p6_gov
chk '电源 SATA 逐口 max_performance' p6_sata
chk '电源 睡眠四 target masked'      p6_masked
chk '电源 dconf 会话值生效（须桌面会话在位）' p6_dconf
chk 'UKUI 任务栏隐藏 hidepanel=true（须桌面会话在位）' p6_panel
chk 'UKUI 显示缩放 scaling-factor=1.5（须桌面会话在位）' p6_scale
chk '音量 pulse Master [100%][on]（须桌面会话在位）' p6_vol
chk '音量 hw Master [100%][on]'                   p6_vol_hw
chk '系统 dpkg --audit 无输出'       p6_audit
chk '系统 python3→3.12'              p6_py
if [ "$P6_FAILS" -eq 0 ]; then
  printf "\n${C_G}================= PROVISION-ALL-GREEN（206 整机总装完成·重启后全量总验通过） =================${C_0}\n"
else
  fail "总验 $P6_FAILS 项 FAIL（见上 [FAIL] 行）——逐项修复后重跑 P6"
fi
fi
