#!/bin/bash
# ============================================================
# 随航自动触发体系 - 卸载脚本
# 用途：彻底移除所有随航自动触发相关文件和服务
# 用法：bash uninstall.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${YELLOW}[i]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }

HOME_DIR="$HOME"
APP_SUPPORT="$HOME_DIR/Library/Application Support/Mac电脑管理"
LAUNCH_AGENTS="$HOME_DIR/Library/LaunchAgents"
APP_DEST="/Applications/随航开关.app"

echo "=============================================="
echo "  随航自动触发体系 卸载"
echo "=============================================="
echo "将移除：脚本、菜单栏 App、3 个启动服务"
echo ""
read -r -p "确认卸载？(y/N) " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "已取消"
  exit 0
fi

# ---------- 1. 停止并移除服务 ----------
info "停止服务..."
UID_NUM=$(id -u)
for lbl in com.kuck.sidecar-watch com.kuck.sidecar-edge-watch com.kuck.sidecar-menu; do
  launchctl bootout "gui/$UID_NUM/$lbl" 2>/dev/null || true
done
sleep 1

# ---------- 2. 删除 plist ----------
info "删除启动服务配置..."
for p in com.kuck.sidecar-watch com.kuck.sidecar-edge-watch com.kuck.sidecar-menu; do
  rm -f "$LAUNCH_AGENTS/$p.plist"
done

# ---------- 3. 删除 App ----------
info "删除菜单栏 App..."
rm -rf "$APP_DEST"

# ---------- 4. 删除脚本 ----------
info "删除脚本..."
rm -f "$APP_SUPPORT/随航触发.sh"
rm -f "$APP_SUPPORT/随航边沿守护.sh"
# 若目录空了则删除目录本身
rmdir "$APP_SUPPORT" 2>/dev/null || true

# ---------- 5. 停止 App 进程 ----------
pkill -f "随航开关.app/Contents/MacOS" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  ✅ 卸载完成"
echo "=============================================="
echo "已移除所有随航自动触发组件。"
echo "（辅助功能授权中残留的 BASH 项属系统记录，可保留不影响）"
echo "=============================================="
