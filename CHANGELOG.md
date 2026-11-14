# Changelog / 更新记录

## v1.0.1 — 2026-11-14

Initial public release.

- One native background process reads compatible Logitech receiver mice directly over HID++, without BTT or Logitech software.
- Publishes accessory power-source data for the built-in macOS Batteries widget.
- Automatically identifies mice, reads reported charge state, and retains temporary missed readings for up to five minutes.
- Handles receiver removal separately and rejects late results from removed connections.
- Adds a macOS installer, login startup, uninstaller, source distribution, and lifecycle/package checks.
- Targets Apple silicon and macOS 14.0 or later. Physical validation currently covers M550 on macOS 27.0.1 only.

首次公开发布。

- 单个原生后台进程通过 HID++ 直接读取兼容罗技接收器鼠标，不依赖 BTT 或罗技软件。
- 向系统提供配件电池信息，供原生“电池”小组件显示。
- 自动识别型号与设备报告的充电状态，临时漏读保留最多五分钟。
- 区分接收器断开，拒绝已断开连接返回的旧读数。
- 提供安装包、登录启动、卸载工具、完整源码及相关检查。
- 面向 M 系列 Mac、macOS 14.0 及以上；目前仅 M550 与 macOS 27.0.1 完成实测。
