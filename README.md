# Logitech Battery Bridge

Read battery levels from compatible Logitech mice connected through a USB receiver and show them in the built-in macOS Batteries widget. The app has a main window, a simple mouse app icon, and an optional mouse icon in the menu bar.

[简体中文](#简体中文) · [Download the latest installer](https://github.com/drfcy/logitech-battery-bridge/releases/latest)

## Features

- Reads Logitech HID++ 2.0 battery reports and publishes accessory battery records to macOS.
- Shows battery, connection, and update status in a native main window.
- Lets you assign a saved display name per mouse; the name also appears in the Batteries widget.
- The menu bar icon can be hidden. When hidden, the app also stays out of the Dock; double-click the app in Applications to reopen its window.
- Continues reading in the background while the window is closed. Battery polling runs once per minute and retries briefly when a sleeping mouse does not respond.
- Detects receiver removal and reconnects automatically.

## Requirements and verified hardware

- Apple silicon Mac and macOS 14.0 or later.
- A compatible Logitech mouse connected through a USB receiver. HID++ battery features `0x1004` and `0x1000` are supported.
- Physical testing: Signature M550 and PRO X 2 over a receiver on macOS 27.0.1.

Other mouse models, Bluetooth-direct reads, and charging transitions may depend on device support. This independent project is not affiliated with Logitech or Apple. Battery publication uses private IOKit interfaces and may need changes after a macOS update.

## Install

Download `LogitechBatteryBridge-1.3.1-macOS14plus-arm64.pkg` from [Releases](https://github.com/drfcy/logitech-battery-bridge/releases/latest), open it, and follow Installer. Administrator authorization is required. The installer places the app in `/Applications` and configures background login startup.

The package and app are not Developer ID signed or notarized. Follow any macOS prompts in System Settings → Privacy & Security, including Input Monitoring if requested.

After installing, connect the receiver and add Apple's Batteries widget from the desktop's Edit Widgets menu. The first reading may take about a minute. Open the main window by double-clicking the app in Applications. Close the window to leave battery reporting in the background. Choose Quit from the menu bar menu to stop it.

Logs: `~/Library/Logs/LogitechBatteryBridge/bridge.log`.

## Build and checks

Developers need Python 3 and Xcode command-line tools. End users do not.

```sh
python3 Tests/run_tests.py
python3 build_installer.py
python3 Tests/verify_package.py dist/LogitechBatteryBridge-1.3.1-macOS14plus-arm64.pkg
```

A hardware integration check for receiver reconnect behavior is available at `IntegrationTests/run.py`; run it with a compatible mouse connected and awake.

The app source and installer sources are also bundled in the installed app at `Contents/Resources/Source/`.

## License and credits

GPL-3.0. HID++ transport code is adapted from [APKiwi/Squeak](https://github.com/APKiwi/Squeak); see [ATTRIBUTION.md](ATTRIBUTION.md).

## 简体中文

通过 USB 接收器读取兼容罗技鼠标的电量，并显示在 macOS 自带的“电池”小组件中。程序包含主窗口和简洁鼠标 App 图标，也可在菜单栏显示鼠标图标。

### 功能

- 读取罗技 HID++ 2.0 电量并发布给 macOS。
- 主窗口显示鼠标电量、连接方式和更新时间。
- 可按鼠标设置显示名称，并同步到系统电池小组件。
- 可隐藏菜单栏图标；开启后程序坞图标也会消失。双击“应用程序”中的 App 可重新打开窗口。
- 关闭窗口后继续后台运行，每分钟读取一次；睡眠鼠标暂时无响应时会短暂重试。
- 接收器断开后自动恢复连接。

### 系统要求与已验证设备

- M 系列 Mac，macOS 14.0 或更新版本。
- USB 接收器连接，支持 HID++ 电量特性 `0x1004` 或 `0x1000` 的罗技鼠标。
- 已实测：Signature M550、PRO X 2，macOS 27.0.1。

其他型号、蓝牙直连读取和充电状态取决于设备支持。本项目与罗技、苹果没有官方关联。系统电池信息使用私有 IOKit 接口，macOS 更新后可能需要调整。

### 安装与使用

在 [GitHub Releases](https://github.com/drfcy/logitech-battery-bridge/releases/latest) 下载 `LogitechBatteryBridge-1.3.1-macOS14plus-arm64.pkg`，双击后按安装器提示操作，需要管理员授权。安装器会将 App 放入“应用程序”，并配置登录后后台运行。

安装包未使用 Apple Developer ID 签名或公证。若 macOS 提示阻止运行，请按“系统设置 → 隐私与安全性”的实际提示操作；若请求输入监控权限，也需授权。

连接接收器后，可在桌面“编辑小组件”里添加苹果“电池”小组件。首次读取可能需要约一分钟。双击“应用程序”里的 App 打开主窗口。关闭窗口后仍在后台上报电量；从菜单中选择“退出”可停止程序。

日志位置：`~/Library/Logs/LogitechBatteryBridge/bridge.log`。卸载时运行 App 包内 `Contents/Resources/卸载.command`。

### 构建与许可

开发者需要 Python 3 和 Xcode 命令行工具；普通安装和运行不需要。源码使用 GPL-3.0，HID++ 代码来源及修改说明见 [ATTRIBUTION.md](ATTRIBUTION.md)。
