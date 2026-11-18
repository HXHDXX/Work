#!/usr/bin/env bash
# 用途：206/dm8 交付包自检——install_dm8_qt.sh 存量 /dm8 布局沿用（dm-home adopt）真值表
# 用法：bash test-install-paths.sh [install_dm8_qt.sh 路径]，缺省取本脚本同目录下的 install_dm8_qt.sh
# 真值表测试：install_dm8_qt.sh 的存量 /dm8 沿用逻辑
# 从真实脚本按标记抽取决策块；块缺失 = RED
set -u
SCRIPT="${1:-$(dirname "$(readlink -f "$0")")/install_dm8_qt.sh}"
[ -f "$SCRIPT" ] || { echo "HARNESS_ERR: script not found: $SCRIPT"; exit 2; }
DEFAULT=$(sed -n 's/^DM_HOME="${DM_HOME:-\([^"]*\)}"/\1/p' "$SCRIPT" | head -1)
[ -n "$DEFAULT" ] || { echo "HARNESS_ERR: 未能从脚本提取 DM_HOME 默认值"; exit 2; }
BLOCK=$(sed -n '/--- dm-home adopt begin ---/,/--- dm-home adopt end ---/p' "$SCRIPT")
[ -n "$BLOCK" ] || { echo "RED: adopt block absent"; exit 1; }
printf '%s\n' "$BLOCK" | grep -q '^# --- dm-home adopt end ---$' || { echo "RED: adopt block unbounded (end marker missing)"; exit 1; }

info() { :; }
run_case() { # $1=expected $2=legacy_root $3=set(DM_HOME value) or unset
  local exp="$1" leg="$2" got
  got=$(bash -c '
    info() { :; }
    [ "${2:-}" = SET ] && export DM_HOME=/x || unset DM_HOME
    DM_HOME_WAS_SET="${DM_HOME+x}"
    DM_HOME="${DM_HOME:-'"$DEFAULT"'}"
    LEGACY_DM_HOME="'"$leg"'"
    eval "$1"
    echo "$DM_HOME"' _ "$BLOCK" "${3:-unset}")
  if [ "$got" = "$exp" ]; then echo "PASS exp=$exp got=$got"; else echo "FAIL exp=$exp got=$got"; return 1; fi
}

T=$(mktemp -d /tmp/dmhome-test.XXXXXX) || { echo "HARNESS_ERR: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/dm8/bin" "$T/dm8/data/DAMENG" "$T/dm8n/bin" "$T/dm8n/data/DAMENG/DAMENG"
printf '#!/bin/sh\n' > "$T/dm8/bin/dmserver"; chmod +x "$T/dm8/bin/dmserver"
touch "$T/dm8/data/DAMENG/dm.ini"
printf '#!/bin/sh\n' > "$T/dm8n/bin/dmserver"; chmod +x "$T/dm8n/bin/dmserver"
touch "$T/dm8n/data/DAMENG/DAMENG/dm.ini"

rc=0
run_case "$T/dm8"   "$T/dm8"  unset || rc=1   # ①存量单层布局→沿用
run_case "$DEFAULT" "$T/none" unset || rc=1   # ②无存量→新默认
run_case "/x"       "$T/dm8"  SET   || rc=1   # ③显式设置→尊重
run_case "$T/dm8n"  "$T/dm8n" unset || rc=1   # ④存量嵌套布局→沿用
exit $rc
