#!/usr/bin/env bash
# =============================================================================
# apt 隧道开关（设备侧）—— 借道工作本机的 ssh -R 让离线设备走 Kylin 官方 apt 源
# 背景判例 2026-11-19：镜像换血（gf0.2→gf0.4）后 kit 预存 debs 严格失配，
#   apt 按当前基线自动选版才是正解；现场总有能上网的工作本机可当出口。
#
# 本机侧先开隧道（保持会话开着）:
#   ssh -R 3142:archive.kylinos.cn:80 -R 3143:archive2.kylinos.cn:80 kylin@<设备IP>
# 设备侧:
#   sudo bash apt-tunnel.sh on     # 写 99tunnel 代理 + apt-get update 自验（失败自动回滚）
#   sudo bash apt-tunnel.sh off    # 用毕删除代理配置
#   sudo bash apt-tunnel.sh check
# =============================================================================
set -e
CONF=/etc/apt/apt.conf.d/99tunnel
case "${1:-check}" in
  on)
    (exec 3<>/dev/tcp/127.0.0.1/3142) 2>/dev/null \
      || { echo "FAIL: 127.0.0.1:3142 不通——先在本机开 ssh -R（见文件头注释）"; exit 1; }
    printf 'Acquire::http::Proxy "http://127.0.0.1:3142";\nAcquire::http::Proxy::archive2.kylinos.cn "http://127.0.0.1:3143";\n' > "$CONF"
    apt-get update || { rm -f "$CONF"; echo "FAIL: apt-get update 不通，已回滚 $CONF"; exit 1; }
    echo "OK: apt 隧道已启用（用毕 sudo bash $0 off）" ;;
  off) rm -f "$CONF" && echo "OK: 已移除 $CONF" ;;
  check) [ -f "$CONF" ] && echo "on" || echo "off" ;;
esac
