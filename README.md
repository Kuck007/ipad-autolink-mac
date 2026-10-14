# iPad 随航一键连接（ipad-autolink-mac）

让 **任何 Mac** 插上 iPad 就自动连上随航（Sidecar），把 iPad 当作显示器使用。换机、重置、给别人用，一条命令装好，永久复用。

![macOS](https://img.shields.io/badge/macOS-14%2B-black) ![License](https://img.shields.io/badge/license-GPL--3.0-orange)

---

## ✨ 功能特性

- **插上即连**：iPad 通过 USB 插入，几秒内自动触发随航，无需任何手动操作
- **边沿守护**：检测 iPad *插入瞬间*（而非"一直插着"），插入即自动拉起服务 + 菜单栏开关（兜底恢复，远程不被打扰）
- **菜单栏开关**：菜单栏常驻图标，一键开/关随航触发，远程时关闭不干扰
- **开机自启**：登录后自动运行，无需每次手动开启
- **全自动兜底**：远程结束忘了重新打开？重插一下 iPad 即自动恢复

---

## 📦 快速开始

### 安装（3 步）

**下载 Release zip（推荐普通用户）**：到 [Releases](https://github.com/Kuck007/ipad-autolink-mac/releases) 下载 `ipad-autolink-mac-v1.0.1.zip`，解压，进入「随航一键安装」文件夹，**右键 `install.sh` → 打开**。

**或用命令行（clone / 拷贝项目后）**：

```bash
# 1. 进入本项目目录
# 2. 运行安装脚本
bash install.sh

# 3. 授权辅助功能（唯一手动步骤）：
#    系统设置 → 隐私与安全性 → 辅助功能 → 打开 BASH(/bin/bash)
```

装完插上 iPad，几秒内自动连上随航。

### 卸载

```bash
bash uninstall.sh
```

---

## ⚠️ 三个硬前提（缺一不可）

| 前提 | 说明 |
|------|------|
| **iPad 支持随航** | iPad Pro / iPad 6 代+ / iPad Air 3 代+ / iPad mini 5 代+ |
| **同一 Apple ID** | iPad 和 Mac 必须登录同一 Apple ID；**设备名无所谓**，任意名字都能识别 |
| **Mac 至少有一个屏幕** | 无屏 Mac（如 Mac mini）需用 BetterDisplay 挂虚拟屏，随航后设 iPad 为主屏、虚拟屏镜像 iPad |

---

## 🧩 架构

```
iPad 插入
   │
   ▼
随航边沿守护.sh  ← 检测"插入瞬间"，拉起服务+App
   │
   ▼
随航触发.sh      ← 每5秒检测，AppleScript 触发随航
   │
   ▼
随航开关.app     ← 菜单栏图标，手动开/关
```

三个 launchd 服务管理：`com.kuck.sidecar-watch`（触发）、`com.kuck.sidecar-edge-watch`（边沿守护）、`com.kuck.sidecar-menu`（菜单栏）。

---

## 📁 项目结构

```
├── install.sh          # 一键安装（路径自适应，换机可复用）
├── uninstall.sh        # 一键卸载
├── 使用说明.md          # 详细使用文档
└── 文件/
    ├── 随航触发.sh      # 每5秒检测+触发随航
    ├── 随航边沿守护.sh  # 插入瞬间兜底恢复
    ├── 随航开关.app     # 菜单栏开关
    └── 模板/            # launchd plist 模板
```

---

## 🧰 面向开发者

- **换机复用**：install.sh 用 `__HOME__` 占位符，自动适配当前用户目录，拷到任意 Mac 直接装
- **路径自适应**：无需改任何配置，安装时自动替换路径
- **踩坑记录**：TCC 目录拦截、launchd 拉 GUI App 失败、随航激活判断等经验见 `使用说明.md`
