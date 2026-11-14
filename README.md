# Logitech Battery Bridge

Show compatible Logitech receiver mouse batteries in the **built-in macOS Batteries widget**.

[English](#english) · [简体中文](#简体中文) · [Download](https://github.com/drfcy/logitech-battery-bridge/releases/latest)

## English

Logitech Battery Bridge reads battery reports directly from supported Logitech HID++ devices and publishes accessory power-source records to macOS. It runs as one background process, without BetterTouchTool, Logi Options+, G HUB, or a Python runtime.

### Requirements and validation

- Apple silicon Mac (M series). The distributed installer does **not** support Intel Macs.
- macOS **14.0 or later** is the deployment and installer target.
- A compatible Logitech mouse connected through a USB receiver. HID++ 2.0 battery features `0x1004` and `0x1000` are supported.
- Hardware verified: **Signature M550, receiver `0xC548`, macOS 27.0.1**.

macOS 14, 15, and 26 have **not been tested on physical machines**. A successful build for macOS 14 does not guarantee identical widget behavior on every release. Other mouse models, real charging transitions, Bluetooth-direct reads, and sleep/wake recovery also need hardware validation. This is an independent project, not affiliated with Logitech or Apple.

### Install

1. Download `LogitechBatteryBridge-1.0.1-macOS14plus-arm64.pkg` from [Releases](https://github.com/drfcy/logitech-battery-bridge/releases/latest).
2. Double-click the package and follow Installer. Administrator authorization is required.
3. Connect your receiver, then right-click the desktop → **Edit Widgets** → add Apple's **Batteries** widget. Allow about a minute for the first scan.

The package installs `/Applications/LogitechBatteryBridge.app` and a system-wide LaunchAgent. It attempts to start the service for the currently logged-in user; otherwise, log out and back in. The app has no main window. Search for `LogitechBatteryBridge` in Activity Monitor to find it. Existing prototype launch settings for the current user are backed up and replaced.

The package is **not Developer ID signed or notarized**; the app only has a local ad-hoc signature. macOS may block it. Follow the actual prompts in **System Settings → Privacy & Security**, including an Input Monitoring request if one appears. See [Apple's instructions](https://support.apple.com/en-us/102445).

### Behavior

- Automatically identifies supported mice and their names; no hard-coded M550 name.
- Reads percentage and reported discharging, charging, or full status. Charging status is not inferred from a rising percentage.
- Scans again 60 seconds after the previous scan finishes, with a short retry if no mouse answers.
- Retains the last successful reading for up to five minutes during a temporary missed response. This is a cached reading, not a fresh measurement.
- On a receiver termination notification, withdraws the associated records without waiting for the next battery poll. Other receivers and native Bluetooth battery entries are left alone.
- Rejects late scan results from removed connections and uses a per-user process lock to prevent duplicate instances.

Widget rendering is scheduled by macOS and may lag behind a record update. The HID++ transport code is adapted from [APKiwi/Squeak](https://github.com/APKiwi/Squeak). Accessory publication uses **private IOKit interfaces** and may break after an OS update.

### Uninstall and diagnostics

Download and run `Uninstall-LogitechBatteryBridge.command` from the Release, or right-click the app → **Show Package Contents** → `Contents/Resources/卸载.command`. Administrator authorization is required. Logs and historical configuration backups remain in each user's Library.

Logs: `~/Library/Logs/LogitechBatteryBridge/bridge.log`

Read a battery once without publishing it:

```sh
/Applications/LogitechBatteryBridge.app/Contents/MacOS/LogitechBatteryBridge --once
```

### Build and test

Developers need Python 3 and Xcode command-line tools. End users do not.

```sh
xcode-select --install  # Only if development tools are not installed
python3 Tests/run_tests.py
python3 build_installer.py
python3 Tests/verify_package.py dist/LogitechBatteryBridge-1.0.1-macOS14plus-arm64.pkg
```

The installer is written to `dist/`. Tests cover cached-reading expiration, receiver removal, multiple mice per receiver, stale scan results, reconnection, and charging/full field mapping with a fake IOKit publisher. They do not replace physical device tests.

To compile only the executable:

```sh
mkdir -p dist
swiftc -O -target arm64-apple-macos14.0 -framework IOKit HIDPP.swift main.swift -o dist/LogitechBatteryBridge
```

### License and credits

[GPL-3.0](LICENSE). The HID++ implementation is adapted from APKiwi/Squeak, with its provenance and local changes recorded in [ATTRIBUTION.md](ATTRIBUTION.md). Full build sources and the license are also included in the installed app under `Contents/Resources/Source/`.

## 简体中文

将兼容的罗技接收器鼠标电量显示在 **macOS 自带的“电池”小组件**中。

程序直接通过 HID++ 读取鼠标电量，再将其上报为系统的配件电池信息。后台只有一个常驻进程，不依赖 BetterTouchTool、Logi Options+、G HUB 或 Python 运行环境。

### 系统要求与验证范围

- **M 系列 Mac**；当前安装包不支持 Intel Mac。
- 安装及编译目标为 **macOS 14.0 及以上**。
- 通过 USB 接收器连接、支持 HID++ 2.0 电量特性 `0x1004` 或 `0x1000` 的罗技鼠标。
- 已实测：**Signature M550、`0xC548` 接收器、macOS 27.0.1**。

macOS 14、15、26 尚未实机验证。编译通过、允许安装，不等于各系统的小组件行为已验证。其他型号、实际充电状态切换、蓝牙直连读取及睡眠唤醒恢复也需要进一步实测。本项目与罗技、苹果没有官方关联。

### 安装与使用

1. 在 [Releases](https://github.com/drfcy/logitech-battery-bridge/releases/latest) 下载 `LogitechBatteryBridge-1.0.1-macOS14plus-arm64.pkg`。
2. 双击安装，按提示输入管理员密码。
3. 连接接收器，在桌面右键 → **编辑小组件** → 添加苹果原生“电池”小组件。首次扫描可能需要约一分钟。

安装位置为 `/Applications/LogitechBatteryBridge.app`，同时配置系统级 LaunchAgent，供本机用户登录后自动运行。安装时会尝试立即启动当前用户的后台服务；未启动时可注销后重新登录。程序没有主窗口，可在活动监视器中搜索 `LogitechBatteryBridge`。

安装包**没有 Apple Developer ID 签名或公证**，应用仅作临时本地签名。若系统拦截，按“系统设置 → 隐私与安全性”中的实际提示处理；若请求输入监控权限，也需授权。[苹果相关说明](https://support.apple.com/en-us/102445)

### 功能与限制

- 自动识别兼容鼠标的型号和电量，不再固定读取 M550。
- 根据设备报告区分放电、充电和充满，不根据百分比上涨猜测充电。
- 每轮扫描完成后等待 60 秒再读取；整轮没有回应时短暂重试。
- 临时漏读时保留上次成功读数最多五分钟，这段时间显示的是缓存电量。
- 收到接收器断开通知后撤销对应记录，不必等下一轮电量查询；不影响其他接收器或系统蓝牙原生记录。
- 防止断开后返回的旧查询重新生成记录，并避免同一用户重复运行多个实例。

最终显示刷新由 macOS 调度。电量读取模块改编自 [APKiwi/Squeak](https://github.com/APKiwi/Squeak)；系统电量上报使用私有 IOKit 接口，系统升级后可能失效。

### 卸载、日志与构建

在 Release 下载并运行 `Uninstall-LogitechBatteryBridge.command`，或右键应用 → 显示包内容 → `Contents/Resources/卸载.command`。卸载需要管理员授权，用户日志和历史配置备份会保留。

日志位于 `~/Library/Logs/LogitechBatteryBridge/bridge.log`。构建、测试命令见上方英文部分；仅开发者需要 Python 3 和 Xcode 命令行工具，普通安装和运行不需要。

### 开源许可

采用 [GPL-3.0](LICENSE)，保留上游来源和修改说明，详见 [ATTRIBUTION.md](ATTRIBUTION.md)。安装后的应用也附带完整构建源码与许可证。
