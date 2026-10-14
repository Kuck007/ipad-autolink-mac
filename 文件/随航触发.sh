#!/bin/bash
# ================================================
# 随航自动触发脚本 (sidecar-trigger) — 社区验证方案
# 原理：AppleScript 操作系统设置 → 显示器 → 添加 → 选择 iPad
#       （macOS 无公开 CLI 触发随航，此路径为社区验证可行方案）
# 依赖：辅助功能(Accessibility)授权给运行 osascript 的宿主
# ================================================
set -euo pipefail

IPAD_NAME="iPad"          # BetterDisplay 记录的 iPad 显示名
TRIGGER_LOG="/tmp/sidecar-trigger.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$TRIGGER_LOG"; }

# 检测 iPad 是否通过 USB 连接（用计数避免 pipefail 干扰）
ipad_connected() {
  local n
  n=$(ioreg -l 2>/dev/null | grep -c 'iPad@' || true)
  [ "$n" -gt 0 ]
}

# 检测随航是否已激活（SidecarDisplayAgent 进程常驻不可靠，
# 改用 system_profiler 判断是否存在 Sidecar 显示器 / 是否有多块显示器）
sidecar_active() {
  local prof
  prof=$(system_profiler SPDisplaysDataType 2>/dev/null)
  if echo "$prof" | grep -qi "Sidecar"; then
    return 0
  fi
  # 若无 Sidecar 字样，检查是否有多块显示器（随航会让显示器数 > 1）
  local n
  n=$(echo "$prof" | grep -c "Resolution")
  [ "$n" -gt 1 ]
}

trigger_sidecar() {
osascript <<'APPLESCRIPT'
on findLastTargetIndex(targetItem, itemList)
	set lastIndex to 0
	repeat with i from (count of itemList) to 1 by -1
		if item i of itemList is targetItem then
			set lastIndex to i
			exit repeat
		end if
	end repeat
	return lastIndex
end findLastTargetIndex

do shell script "afplay /System/Library/Sounds/Pop.aiff"

tell application "System Settings"
	activate
	delay 1
	tell application "System Events"
		tell process "System Settings"
			set systemLanguage to do shell script "defaults read -g AppleLocale"
			if systemLanguage starts with "zh" then
				set menuItemName to "显示器"
				set menuBarItemName to "显示"
				set addButtonName to "添加"
			else
				set menuItemName to "Displays"
				set menuBarItemName to "View"
				set addButtonName to "Add"
			end if

			-- 打开"显示器"面板
			click menu item menuItemName of menu menuBarItemName of menu bar item menuBarItemName of menu bar 1
			delay 0.5

			-- 点右边的"添加"按钮，选 iPad
			tell group 1 of group 2 of splitter group 1 of group 1 of window menuItemName
				try
					delay 1
					click pop up button addButtonName
					set menuItems to name of menu items of menu addButtonName of pop up button addButtonName
					set targetIndex to (my findLastTargetIndex("iPad", menuItems))
					delay 0.3
					click menu item targetIndex of menu addButtonName of pop up button addButtonName
					do shell script "afplay /System/Library/Sounds/Blow.aiff"
				on error
					delay 0.5
					do shell script "afplay /System/Library/Sounds/Hero.aiff"
				end try
			end tell
		end tell
	end tell
end tell
delay 1
tell application "System Settings" to quit
APPLESCRIPT
  return $?
}

if ! ipad_connected; then
  log "未检测到 iPad 连接，跳过"
  exit 0
fi

if sidecar_active; then
  log "iPad 已连接且随航已激活，无需操作"
  exit 0
fi

log "检测到 iPad 插入，触发随航..."
if trigger_sidecar; then
  log "随航触发成功"
  exit 0
else
  log "随航触发失败（可能缺少辅助功能授权）"
  exit 1
fi
