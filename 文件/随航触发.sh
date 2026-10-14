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

# 检测随航是否已激活：直接检测 system_profiler 中是否出现 "Sidecar" 显示器。
# 随航激活时会明确列出 "Sidecar Display"（实测 Main Display: Yes）。
# 不能用数 Resolution/Online 行数的方式：BetterDisplay 单块虚拟屏自己就有
# Resolution + Online 两行 = 2，会在随航没连上时误判为已激活。
sidecar_active() {
  system_profiler SPDisplaysDataType 2>/dev/null | grep -qi "Sidecar"
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
		if thisItem is not "" and thisItem is not "missing value" and thisItem is not "镜像或扩展至" and thisItem is not "Mirror or Extend to" then
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

			-- 点右边的"添加"按钮，选设备
			tell group 1 of group 2 of splitter group 1 of group 1 of window menuItemName
				delay 1
				click pop up button addButtonName
				delay 0.8
				-- 用 menu 1（按索引）引用弹出菜单，不依赖菜单名"添加"，更可靠
				set menuItems to name of menu items of menu 1 of pop up button addButtonName
				set targetIndex to (my findLastTargetIndex(menuItems))
				delay 0.3
				if targetIndex > 0 then
					click menu item targetIndex of menu 1 of pop up button addButtonName
					do shell script "afplay /System/Library/Sounds/Blow.aiff"
				else
					do shell script "afplay /System/Library/Sounds/Basso.aiff"
				end if
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
trigger_sidecar

# 不盲信 osascript 退出码：等待后在 shell 层真实验证 Sidecar 是否真的出现。
# 触发动作可能点中后需要几秒建立连接，最多等待约 12 秒。
i=0
while [ $i -lt 6 ]; do
  if sidecar_active; then
    log "随航触发成功（已验证 Sidecar 显示器在线）"
    exit 0
  fi
  sleep 2
  i=$((i+1))
done

log "随航触发失败：触发后未检测到 Sidecar 显示器（可能缺少辅助功能授权或菜单未点中）"
exit 1
