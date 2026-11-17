# Changelog / 更新记录

## v1.3.1 — 2026-11-18

- Hiding the menu bar icon now also hides the Dock icon. The background process remains available, and double-clicking the app in Applications reopens its window.
- Added the mouse app icon, larger name-edit button, and main-window setting text for the hidden state.

开启隐藏后同时移除菜单栏和程序坞图标，后台电量上报继续运行；双击“应用程序”里的 App 可重新打开主窗口。补充鼠标 App 图标、放大名称编辑按钮并说明隐藏状态。

## v1.3.0 — 2026-11-18

- Added a mouse app icon and persistent mouse name editing for the window and Batteries widget.
- Added a setting to hide the menu bar icon and a larger name-edit button.

增加鼠标 App 图标、可保存的鼠标显示名称，以及隐藏菜单栏图标开关和更大的名称编辑按钮。

## v1.2.0 — 2026-11-17

- Added the locally drawn mouse app icon and persistent per-device display names in the main window and Batteries widget.

增加简洁鼠标 App 图标，以及可保存并同步到主窗口和电池小组件的鼠标显示名称。

## v1.1.0 — 2026-11-17

- Added the native main window, battery and connection status, manual refresh, and log access.
- Kept the bridge running after the window closes; exiting stops it cleanly.

新增主窗口、电量与连接状态、手动刷新和日志入口；关闭窗口后继续运行，退出时正常停止。

## v1.0.2 — 2026-11-17

- Improved receiver removal and reconnect handling after the 2.4 GHz receiver is unplugged.

修复 2.4G 接收器拔插后的设备重连处理。

## v1.0.1 — 2026-11-14

Initial public release for Apple silicon and macOS 14 or later, with HID++ battery reading, system widget publication, installer, login startup, and uninstaller.

首次公开发布，支持 M 系列 Mac 和 macOS 14 及以上版本，包含 HID++ 电量读取、系统小组件上报、安装、登录启动和卸载工具。
