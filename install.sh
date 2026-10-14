#!/bin/bash
# ============================================================
# 随航自动触发体系 - 一键安装脚本
# 用途：在任意 Mac 上安装"插 iPad 自动随航"全套（换机/重置/给别人都能用）
# 用法：把整个"随航一键安装"文件夹拷到 Mac 上，然后运行：
#       bash install.sh
# 或：双击文件夹里的 install.command（会自动打开终端）
# ============================================================
set -euo pipefail

# ---------- 颜色输出 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${YELLOW}[i]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }

# ---------- 自动定位脚本所在目录（兼容从任意位置运行） ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- 目标路径 ----------
HOME_DIR="$HOME"
APP_SUPPORT="$HOME_DIR/Library/Application Support/Mac电脑管理"
LAUNCH_AGENTS="$HOME_DIR/Library/LaunchAgents"
APP_DEST="/Applications/随航开关.app"

echo "=============================================="
echo "  随航自动触发体系 一键安装"
echo "=============================================="
echo "当前用户: $(whoami)"
echo "用户目录: $HOME_DIR"
echo ""

# ---------- 1. 检查系统要求 ----------
info "检查系统要求..."
if [ "$(uname)" != "Darwin" ]; then
  err "此安装包仅支持 macOS"
  exit 1
fi

# 检查是否有 iPad（仅提示，不强制）
if ioreg -l 2>/dev/null | grep -q 'iPad@'; then
  ok "检测到 iPad 已连接"
  # 脚本与设备名解耦，任意名字都能识别
  IPAD_NAME_RAW=$(ioreg -l 2>/dev/null | grep -o 'iPad@[^<]*' | head -1)
  if [ -n "$IPAD_NAME_RAW" ]; then
    info "检测到设备: $IPAD_NAME_RAW"
  fi
  info "设备名无所谓，任意名字都能自动连；请确保 iPad 与 Mac 登录同一 Apple ID"
else
  info "未检测到 iPad（安装时可以不插，插上即自动生效；设备名任意，需同一 Apple ID）"
fi

# ---------- 2. 创建目标目录 ----------
info "创建目录..."
mkdir -p "$APP_SUPPORT"
mkdir -p "$LAUNCH_AGENTS"
ok "目录已就绪: $APP_SUPPORT"

# ---------- 3. 拷贝脚本 ----------
info "拷贝触发脚本..."
cp "$SCRIPT_DIR/文件/随航触发.sh"     "$APP_SUPPORT/随航触发.sh"
cp "$SCRIPT_DIR/文件/随航边沿守护.sh" "$APP_SUPPORT/随航边沿守护.sh"
chmod 755 "$APP_SUPPORT/随航触发.sh"
chmod 755 "$APP_SUPPORT/随航边沿守护.sh"
ok "脚本已安装"

# ---------- 4. 拷贝菜单栏 App ----------
info "安装菜单栏 App（随航开关）..."
if [ -d "$SCRIPT_DIR/文件/随航开关.app" ]; then
  # 先移除旧版本（如果有）
  rm -rf "$APP_DEST"
  cp -R "$SCRIPT_DIR/文件/随航开关.app" "$APP_DEST"
  # 设置 App 权限和打开隔离
  chmod -R 755 "$APP_DEST"
  xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
  ok "App 已安装到 /Applications"
else
  info "未找到 App（不影响核心随航触发，但菜单栏开关不可用）"
fi

# ---------- 5. 生成 3 个 plist（替换 __HOME__ 为实际用户目录） ----------
info "生成启动服务配置..."
gen_plist() {
  local template="$1" dest="$2"
  sed "s|__HOME__|$HOME_DIR|g" "$template" > "$dest"
  chmod 644 "$dest"
  plutil -lint "$dest" >/dev/null 2>&1 || { err "plist 语法错误: $dest"; exit 1; }
}
gen_plist "$SCRIPT_DIR/文件/模板/com.kuck.sidecar-watch.plist"     "$LAUNCH_AGENTS/com.kuck.sidecar-watch.plist"
gen_plist "$SCRIPT_DIR/文件/模板/com.kuck.sidecar-edge-watch.plist" "$LAUNCH_AGENTS/com.kuck.sidecar-edge-watch.plist"
gen_plist "$SCRIPT_DIR/文件/模板/com.kuck.sidecar-menu.plist"       "$LAUNCH_AGENTS/com.kuck.sidecar-menu.plist"
ok "3 个启动服务配置已生成"

# ---------- 6. 加载服务 ----------
info "加载服务..."
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM/com.kuck.sidecar-watch"     2>/dev/null || true
launchctl bootout "gui/$UID_NUM/com.kuck.sidecar-edge-watch" 2>/dev/null || true
launchctl bootout "gui/$UID_NUM/com.kuck.sidecar-menu"      2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$LAUNCH_AGENTS/com.kuck.sidecar-watch.plist"
launchctl bootstrap "gui/$UID_NUM" "$LAUNCH_AGENTS/com.kuck.sidecar-edge-watch.plist"
launchctl bootstrap "gui/$UID_NUM" "$LAUNCH_AGENTS/com.kuck.sidecar-menu.plist"
ok "服务已加载"

# ---------- 7. 检查辅助功能授权 ----------
info "检查辅助功能授权..."
osascript -e 'tell application "System Events" to get name of first process' >/dev/null 2>&1
if [ $? -ne 0 ]; then
  err "检测到尚未授予辅助功能权限！"
  echo ""
  echo "  ⚠️  关键一步（必须手动完成）："
  echo "  打开：系统设置 → 隐私与安全性 → 辅助功能"
  echo "  找到：BASH（或 /bin/bash）→ 打开开关"
  echo "  或者：安装器触发的弹窗里点『打开系统设置』并授权"
  echo ""
  echo "  不授权的话，脚本无法操作系统设置，随航不会自动触发。"
  echo "  授权后无需重启，插上 iPad 即可自动连随航。"
else
  ok "辅助功能已授权"
fi

# ---------- 8. 启动菜单栏 App（仅当未运行，避免与 plist 自启产生重复实例）----------
if pgrep -f "随航开关.app/Contents/MacOS" >/dev/null 2>&1; then
  ok "菜单栏 App 已在运行（登录自启已拉起），不再重复打开"
else
  open -a "$APP_DEST" 2>/dev/null || true
  sleep 1
  ok "菜单栏 App 已启动"
fi

echo ""
echo "=============================================="
echo "  ✅ 安装完成！"
echo "=============================================="
echo "现在：插上 iPad，它会在几秒内自动连上随航"
echo "菜单栏出现『随航开关』图标，可手动开/关"
echo ""
echo "如需卸载，运行: bash uninstall.sh"
echo "（若上面有红色『辅助功能』提示，请先完成授权）"
echo "=============================================="
