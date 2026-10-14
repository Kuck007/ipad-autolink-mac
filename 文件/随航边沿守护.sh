#!/bin/bash
# ================================================
# 随航边沿守护 (sidecar-edge-watch)
# 作用：检测 iPad 插入的【瞬间】（从无→有），自动拉起 sidecar-watch 服务
# 设计要点：
#   - 边沿检测：记录上一次 iPad 是否插入，只在"无→有"的瞬间触发
#   - 启动时先把当前状态作为基线，避免一启动就误判触发
#   - 只拉起服务，不重复触发逻辑（触发仍由 sidecar-trigger.sh 每5秒做）
#   - 不打扰远程：iPad 一直插着时没有"瞬间"，不会误触发
# ================================================
set -uo pipefail

UID_NUM=$(id -u)
LABEL="com.kuck.sidecar-watch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# 菜单栏开关 App（绝对路径，避免 launchd 环境变量问题）
APP_PATH="/Applications/随航开关.app"
LOG="/tmp/sidecar-edge-watch.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG"; }

# 检测 iPad 是否插入（返回 0=未插, 1=已插）
ipad_present() {
  local n
  n=$(ioreg -l 2>/dev/null | grep -c 'iPad@' || true)
  [ "$n" -gt 0 ] && echo 1 || echo 0
}

# 拉起 sidecar-watch 服务（若未加载）
ensure_service() {
  if ! launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    if launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
      log "检测到 iPad 插入瞬间 → 已拉起 $LABEL 服务"
    else
      log "检测到 iPad 插入瞬间 → 尝试拉起服务失败"
    fi
  else
    log "检测到 iPad 插入瞬间，但服务已在运行，无需操作"
  fi
}

# 拉起菜单栏开关 App（若进程未运行）
# 用 open -a 启动（能正确连接 GUI 会话），用 pgrep 判断 App 是否真的在跑
ensure_menu() {
  if pgrep -f "随航开关.app/Contents/MacOS" >/dev/null 2>&1; then
    log "检测到 iPad 插入瞬间，菜单栏 App 已在运行"
    return 0
  fi
  if open -a "$APP_PATH" >/dev/null 2>&1; then
    log "检测到 iPad 插入瞬间 → 已打开菜单栏 App（随航开关）"
  else
    log "检测到 iPad 插入瞬间 → 尝试打开菜单栏 App 失败"
  fi
}

# ---- 启动：先把当前状态作为基线（防误判）----
PREV=$(ipad_present)
log "守护启动，当前 iPad 状态: $PREV（作为基线）"

while true; do
  CUR=$(ipad_present)
  # 边沿检测：无→有 的瞬间
  if [ "$PREV" = "0" ] && [ "$CUR" = "1" ]; then
    ensure_service
    ensure_menu
  fi
  PREV=$CUR
  sleep 1
done
