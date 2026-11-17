// GPL-3.0. Native window and status item, 2026-11-17.
import AppKit
import SwiftUI
import Combine

let showBridgeWindow = Notification.Name("local.logitech.batterybridge.showWindow")

struct DashboardDevice: Identifiable {
    var id: String { reading.id }
    let reading: DeviceReading
    let readAt: Date
}

// Mutated on the main queue; HID requests remain on the serial polling queue.
final class DashboardModel: ObservableObject {
    @Published private(set) var devices: [DashboardDevice] = []
    @Published private(set) var refreshing = false
    @Published private(set) var receiverCount = 0
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var currentIDs = Set<String>()
    @Published private(set) var aliases: [String: String]
    @Published private(set) var hideMenuBarIcon: Bool
    private let names: DeviceNames

    init(names: DeviceNames = DeviceNames()) {
        self.names = names
        aliases = names.snapshot
        hideMenuBarIcon = UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
    }

    func setHideMenuBarIcon(_ hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: "hideMenuBarIcon")
        hideMenuBarIcon = hidden
    }

    func displayName(_ device: DashboardDevice) -> String { aliases[device.id] ?? device.reading.name }

    @discardableResult func renameDevice(_ id: String, name: String) throws -> String {
        guard let device = devices.first(where: { $0.id == id }) else {
            throw NSError(domain: "Dashboard", code: 1, userInfo: [NSLocalizedDescriptionKey: "设备已断开，请重新连接后再修改名称。"])
        }
        try names.setAlias(name, for: id)
        aliases = names.snapshot
        return displayName(device)
    }

    func beginRefresh() { refreshing = true }

    func finishRefresh(_ readings: [DeviceReading], receiverCount: Int,
                       now: Date = Date(), isConnected: (UInt64) -> Bool = connectionIsPresent) {
        self.receiverCount = receiverCount
        lastAttempt = now
        refreshing = false
        var retained = Dictionary(uniqueKeysWithValues: devices.filter {
            now.timeIntervalSince($0.readAt) < 300 && isConnected($0.reading.connectionID)
        }.map { ($0.id, $0) })
        currentIDs.removeAll()
        for reading in readings where isConnected(reading.connectionID) {
            guard let percent = reading.percent, (0...100).contains(percent) else { continue }
            retained[reading.id] = DashboardDevice(reading: reading, readAt: now)
            currentIDs.insert(reading.id)
        }
        devices = retained.values.sorted { $0.reading.name < $1.reading.name }
    }

    func removeConnections(_ ids: Set<UInt64>) {
        let removed = devices.filter { ids.contains($0.reading.connectionID) }
        receiverCount = max(0, receiverCount - Set(removed.map { $0.reading.connectionID }).count)
        devices.removeAll { ids.contains($0.reading.connectionID) }
        currentIDs.subtract(removed.map { $0.id })
    }

    var summary: String {
        if refreshing { return "正在读取电量，通常需要约 20–30 秒…" }
        if receiverCount == 0 { return "等待罗技接收器连接" }
        if currentIDs.isEmpty { return "鼠标暂未回应，请移动鼠标或检查电源" }
        return "电量读取正常 · 接收器拔插后自动恢复"
    }
}

private struct BatteryCard: View {
    let device: DashboardDevice
    let current: Bool
    let name: String
    let rename: () -> Void
    private var reading: DeviceReading { device.reading }
    private var tint: Color {
        if !current { return .secondary }
        return (reading.percent ?? 0) <= 20 ? .orange : .accentColor
    }
    private var stateText: String {
        guard current else { return "上次电量 · 等待鼠标回应" }
        switch reading.state {
        case .charging: return "正在充电"
        case .full: return "已充满"
        case .discharging: return "使用电池"
        case .unknown: return "充电状态未知"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 35)).foregroundStyle(tint)
                    .frame(width: 56, height: 60)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 21, weight: .semibold)).lineLimit(2)
                        Button(action: rename) { Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle()) }
                            .buttonStyle(.borderless).help("修改鼠标名称")
                            .accessibilityLabel("修改鼠标名称")
                    }
                    Label(reading.transport == .receiver ? "2.4G USB 接收器" : "蓝牙连接",
                          systemImage: reading.transport == .receiver ? "antenna.radiowaves.left.and.right" : "wave.3.right")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(reading.percent ?? 0)%")
                    .font(.system(size: 46, weight: .medium, design: .rounded))
                    .monospacedDigit().foregroundStyle(tint)
                    .accessibilityLabel("电量 \(reading.percent ?? 0) 百分比")
            }
            ProgressView(value: Double(reading.percent ?? 0), total: 100).tint(tint)
            HStack {
                Label(stateText, systemImage: reading.state.isOnPower ? "bolt.fill" : "battery.75percent")
                Spacer()
                Text("更新于 \(device.readAt.formatted(date: .omitted, time: .standard))")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.07)))
    }
}

struct DashboardView: View {
    @ObservedObject var model: DashboardModel
    let refresh: () -> Void
    let openLog: () -> Void
    let rename: (String, String) throws -> Void
    @State private var editingDevice: DashboardDevice?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text("罗技电量桥接").font(.system(size: 23, weight: .semibold))
                    Text("读取鼠标电量，同步到系统电池小组件")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Toggle("隐藏菜单栏图标", isOn: Binding(
                    get: { model.hideMenuBarIcon },
                    set: { model.setHideMenuBarIcon($0) }
                ))
                .toggleStyle(.switch)
                Text("同时隐藏程序坞图标，双击应用可再打开窗口")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Text("我的设备").font(.headline)
                Spacer()
                Text("每分钟自动刷新").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 12) {
                    if model.devices.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: model.refreshing ? "antenna.radiowaves.left.and.right" : "computermouse")
                                .font(.system(size: 42, weight: .light)).foregroundStyle(.secondary)
                            Text(model.refreshing ? "正在寻找鼠标…" : "尚未读取到鼠标")
                                .font(.headline)
                            Text(model.refreshing ? "首次读取可能需要约 30 秒" : "连接罗技接收器，并移动鼠标唤醒设备")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 35)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        ForEach(model.devices) { device in
                            BatteryCard(device: device, current: model.currentIDs.contains(device.id), name: model.displayName(device), rename: { editingDevice = device })
                        }
                    }
                }.padding(1)
            }.scrollIndicators(.hidden)
            Divider()
            HStack(alignment: .top, spacing: 9) {
                if model.refreshing {
                    ProgressView().controlSize(.small).scaleEffect(0.8).frame(width: 14, height: 16)
                } else {
                    Circle().fill(model.currentIDs.isEmpty ? Color.orange : Color.green)
                        .frame(width: 7, height: 7).frame(width: 14, height: 16)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.summary).font(.subheadline)
                    if let last = model.lastAttempt {
                        Text("最近检查：\(last.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: refresh) { Label(model.refreshing ? "读取中…" : "立即刷新", systemImage: "arrow.clockwise") }
                    .buttonStyle(.borderedProminent).disabled(model.refreshing).keyboardShortcut("r")
                Button(action: openLog) { Label("打开日志", systemImage: "doc.text") }.buttonStyle(.bordered)
                Spacer()
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.1")")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Text("关闭窗口后仍在后台运行，双击“应用程序”中的 App 可再次打开。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 600, minHeight: 510)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingDevice) { device in
            RenameMouseView(originalName: device.reading.name, initialName: model.displayName(device)) { text in
                try rename(device.id, text)
            }
        }
    }
}

private struct RenameMouseView: View {
    let originalName: String
    let save: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error: String?
    @FocusState private var focused: Bool

    init(originalName: String, initialName: String, save: @escaping (String) throws -> Void) {
        self.originalName = originalName
        self.save = save
        _name = State(initialValue: initialName)
    }

    private func commit() {
        do { try save(name); dismiss() }
        catch { self.error = error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("修改鼠标名称", systemImage: "computermouse.fill").font(.title2.weight(.semibold))
            TextField("鼠标名称", text: $name).textFieldStyle(.roundedBorder)
                .focused($focused).onSubmit(commit)
            Text("用于主窗口和系统电池小组件，重启后保留。\n留空可恢复原名：\(originalName)")
                .font(.subheadline).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存", action: commit).keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }.padding(26).frame(width: 420).onAppear { focused = true }
    }
}

final class DashboardController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model: DashboardModel
    private let background: Bool
    private let refresh: () -> Void
    private let quit: () -> Void
    private let rename: (String, String) throws -> Void
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var hideIconObservation: AnyCancellable?

    init(model: DashboardModel, background: Bool, refresh: @escaping () -> Void, rename: @escaping (String, String) throws -> Void, quit: @escaping () -> Void) {
        self.model = model
        self.background = background
        self.refresh = refresh
        self.quit = quit
        self.rename = rename
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(item("打开主窗口", action: #selector(showWindow), key: ""))
        menu.addItem(item("立即刷新", action: #selector(refreshNow), key: ""))
        menu.addItem(item("打开日志", action: #selector(openLog), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("退出罗技电量桥接", action: #selector(quitApp), key: "q"))
        statusMenu = menu
        hideIconObservation = model.$hideMenuBarIcon
            .removeDuplicates()
            .sink { [weak self] hidden in
                DispatchQueue.main.async { self?.updateMenuBarIcon(hidden: hidden) }
            }
        updateMenuBarIcon(hidden: model.hideMenuBarIcon)
        let main = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("打开主窗口", action: #selector(showWindow), key: "0"))
        appMenu.addItem(.separator())
        appMenu.addItem(item("退出罗技电量桥接", action: #selector(quitApp), key: "q"))
        root.submenu = appMenu
        main.addItem(root)
        let editRoot = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editRoot.submenu = editMenu
        main.addItem(editRoot)
        let windowRoot = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowRoot.submenu = windowMenu
        main.addItem(windowRoot)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showWindow), name: showBridgeWindow, object: nil)
        if !background { showWindow() }
    }

    private func updateMenuBarIcon(hidden: Bool) {
        if hidden {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            NSApp.setActivationPolicy(.accessory)
            return
        }
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let mouseIcon = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "罗技电量桥接")
        mouseIcon?.isTemplate = true
        statusItem?.button?.image = mouseIcon
        statusItem?.button?.toolTip = "罗技电量桥接 · 点击打开菜单"
        statusItem?.menu = statusMenu
        NSApp.setActivationPolicy(window?.isVisible == true ? .regular : .accessory)
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    @objc func showWindow() {
        if window == nil {
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 550),
                                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                   backing: .buffered, defer: false)
            created.title = "罗技电量桥接"
            created.contentView = NSHostingView(rootView: DashboardView(model: model, refresh: refresh, openLog: { [weak self] in self?.openLog() }, rename: rename))
            created.contentMinSize = NSSize(width: 600, height: 510)
            created.isReleasedWhenClosed = false
            created.delegate = self
            created.setFrameAutosaveName("LogitechBatteryBridge.MainWindow")
            created.center()
            window = created
        }
        NSApp.setActivationPolicy(model.hideMenuBarIcon ? .accessory : .regular)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshNow() { if !model.refreshing { refresh() } }
    @objc private func openLog() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/LogitechBatteryBridge/bridge.log")
        NSWorkspace.shared.open(url)
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quit()
        return .terminateLater
    }
}
