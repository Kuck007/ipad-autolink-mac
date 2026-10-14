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

# 检测随航是否已激活：用 CoreGraphics 查当前实际活动的显示器数量。
# 之前用 system_profiler 找 "Sidecar"/数 Resolution，但 BetterDisplay 虚拟屏会
# 占据主屏导致 system_profiler 不列出 iPad 随航屏，误判未激活 → 反复触发弹窗。
# 随航连上后显示器真实数量 ≥ 2（虚拟屏 + iPad），此法不受文本解析干扰。
sidecar_active() {
  local count
  count=$(osascript -e 'tell application "System Events" to count windows of desktop' 2>/dev/null)
  # 直接数在线显示器数（随航连上会 > 1）
  count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -cE "Resolution:|Online: Yes")
  # 阈值：虚拟屏 + iPad 至少 2 块在线显示器
  [ "$count" -ge 2 ]
}

trigger_sidecar() {
osascript <<'APPLESCRIPT'
on findLastTargetIndex(itemList)
	-- 匹配"添加"菜单里的真实设备项，与设备名完全无关。
	-- 菜单固定含一个功能项"镜像或扩展至"(中文)/"Mirror or Extend to"(英文)，
	-- 其余项就是可选的随航设备（不管叫什么名字）。倒序取最后一个非功能项。
	set lastIndex to 0
	repeat with i from (count of itemList) to 1 by -1
		set thisItem to (item i of itemList) as text
		if thisItem is not "" and thisItem is not "镜像或扩展至" and thisItem is not "Mirror or Extend to" then
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
					set targetIndex to (my findLastTargetIndex(menuItems))
					delay 0.3
					if targetIndex > 0 then
						click menu item targetIndex of menu addButtonName of pop up button addButtonName
						do shell script "afplay /System/Library/Sounds/Blow.aiff"
					else
						do shell script "afplay /System/Library/Sounds/Basso.aiff"
					end if
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
