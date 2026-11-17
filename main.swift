// GPL-3.0. Created 2026-11-14. See ATTRIBUTION.md for HIDPPKit provenance.
import Foundation
import IOKit
import Darwin
import AppKit

func connectionIsPresent(_ id: UInt64) -> Bool {
    guard id != 0, let matching = IORegistryEntryIDMatching(id) else { return false }
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else { return false }
    IOObjectRelease(service)
    return true
}

final class PowerPublisher {
    typealias Create = @convention(c) (UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
    typealias Update = @convention(c) (UnsafeMutableRawPointer, CFDictionary) -> Int32
    typealias Release = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private let create: Create
    private let update: Update
    private let release: Release
    private let lock = NSLock()
    private let isConnected: (UInt64) -> Bool
    private let names: DeviceNames?
    private var connections: [String: UInt64] = [:]
    private var removedConnections = Set<UInt64>()
    private var sources: [String: UnsafeMutableRawPointer] = [:]
    private var lastSeen: [String: TimeInterval] = [:]
    private var lastDetails: [String: [String: Any]] = [:]
    // A sleeping device may miss a poll; keep its last reading for at most five minutes.
    private let retention: TimeInterval = 300

    init(createFunction: Create? = nil, updateFunction: Update? = nil,
         releaseFunction: Release? = nil,
         isConnected: @escaping (UInt64) -> Bool = connectionIsPresent,
         names: DeviceNames? = nil) {
        self.isConnected = isConnected
        self.names = names
        guard let lib = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let c = dlsym(lib, "IOPSCreatePowerSource"),
              let u = dlsym(lib, "IOPSSetPowerSourceDetails"),
              let r = dlsym(lib, "IOPSReleasePowerSource") else {
            fatalError("Required IOKit accessory power-source interfaces are unavailable")
        }
        create = createFunction ?? unsafeBitCast(c, to: Create.self)
        update = updateFunction ?? unsafeBitCast(u, to: Update.self)
        release = releaseFunction ?? unsafeBitCast(r, to: Release.self)
    }

    func publish(_ readings: [DeviceReading], now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.lock(); defer { lock.unlock() }
        var seen = Set<String>()
        for device in readings {
            guard let percent = device.percent, (0...100).contains(percent) else { continue }
            guard !removedConnections.contains(device.connectionID), isConnected(device.connectionID) else { continue }
            let identifier = "local.logitech.direct.batterybridge:" + device.id
            connections[identifier] = device.connectionID
            guard seen.insert(identifier).inserted else { continue }
            lastSeen[identifier] = now
            var source = sources[identifier]
            if source == nil {
                let status = create(&source)
                guard status == 0, let created = source else {
                    print("Create failed: \(status)"); continue
                }
                sources[identifier] = created
            }
            let details: [String: Any] = [
                "Name": names?.displayName(for: device) ?? device.name,
                "Type": "Accessory Source",
                "Accessory Category": "Mouse",
                "Accessory Identifier": identifier,
                "Transport Type": device.transport == .bluetooth ? "Bluetooth LE" : "USB",
                "Current Capacity": percent,
                "Max Capacity": 100,
                "Power Source State": device.state.isOnPower ? "AC Power" : "Battery Power",
                "Is Present": true,
                "Is Charging": device.state == .charging,
                "Is Charged": device.state == .full
            ]
            let status = update(source!, details as CFDictionary)
            if status != 0 {
                print("Update failed for \(device.name): \(status)")
                _ = release(source!)
                sources.removeValue(forKey: identifier)
                lastDetails.removeValue(forKey: identifier)
            } else {
                lastDetails[identifier] = details
            }
        }
        for identifier in Array(sources.keys) where !isConnected(connections[identifier] ?? 0) ||
            (!seen.contains(identifier) && now - (lastSeen[identifier] ?? 0) >= retention) {
            _ = release(sources.removeValue(forKey: identifier)!)
            lastSeen.removeValue(forKey: identifier)
            connections.removeValue(forKey: identifier)
            lastDetails.removeValue(forKey: identifier)
        }
    }

    // Change only the published name; do not extend the age of a battery reading.
    func renameDevice(_ id: String, name: String) {
        lock.lock(); defer { lock.unlock() }
        let identifier = "local.logitech.direct.batterybridge:" + id
        guard let source = sources[identifier], var details = lastDetails[identifier],
              let connection = connections[identifier], !removedConnections.contains(connection),
              isConnected(connection) else { return }
        details["Name"] = name
        let status = update(source, details as CFDictionary)
        if status == 0 { lastDetails[identifier] = details }
        else { print("Rename publication failed for \(id): \(status)") }
    }

    func removeConnections(_ ids: Set<UInt64>) {
        lock.lock(); defer { lock.unlock() }
        removedConnections.formUnion(ids)
        for identifier in Array(sources.keys) where ids.contains(connections[identifier] ?? 0) {
            _ = release(sources.removeValue(forKey: identifier)!)
            lastSeen.removeValue(forKey: identifier)
            connections.removeValue(forKey: identifier)
            lastDetails.removeValue(forKey: identifier)
            print("Receiver removed; withdrew battery record: \(identifier)")
        }
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        for source in sources.values { _ = release(source) }
        sources.removeAll()
        lastSeen.removeAll()
        connections.removeAll()
        lastDetails.removeAll()
    }
}

// IOKit termination notifications arrive independently of the minute-long battery poll.
final class ReceiverRemovalMonitor {
    private var port: IONotificationPortRef?
    private var iterator: io_iterator_t = 0
    private let onRemoval: (Set<UInt64>) -> Void

    init(onRemoval: @escaping (Set<UInt64>) -> Void) {
        self.onRemoval = onRemoval
        guard let port = IONotificationPortCreate(kIOMainPortDefault),
              let matching = IOServiceMatching("IOHIDDevice") else {
            fatalError("Cannot create receiver removal monitor")
        }
        self.port = port
        let properties = matching as NSMutableDictionary
        properties["IOPropertyMatch"] = ["VendorID": 0x046D]
        IONotificationPortSetDispatchQueue(port, .main)
        let status = IOServiceAddMatchingNotification(port, kIOTerminatedNotification,
            matching, { context, iterator in
                guard let context else { return }
                Unmanaged<ReceiverRemovalMonitor>.fromOpaque(context).takeUnretainedValue().drain(iterator)
            }, Unmanaged.passUnretained(self).toOpaque(), &iterator)
        guard status == KERN_SUCCESS else { fatalError("Receiver monitor registration failed: \(status)") }
        drain(iterator) // Arm notification delivery.
    }

    private func drain(_ iterator: io_iterator_t) {
        var ids = Set<UInt64>()
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            var id: UInt64 = 0
            if IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS { ids.insert(id) }
            IOObjectRelease(service)
        }
        if !ids.isEmpty { onRemoval(ids) }
    }

    deinit {
        if iterator != 0 { IOObjectRelease(iterator) }
        if let port { IONotificationPortDestroy(port) }
    }
}

// A per-user lock prevents duplicate instances when the app is opened manually.
var instanceLock: Int32 = -1
func prepareRuntime() {
    do {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let support = library.appendingPathComponent("Application Support/LogitechBatteryBridge", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        instanceLock = open(support.appendingPathComponent("bridge.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard instanceLock >= 0 else { fatalError("Cannot open instance lock") }
        if flock(instanceLock, LOCK_EX | LOCK_NB) != 0 {
            DistributedNotificationCenter.default().postNotificationName(showBridgeWindow, object: nil, userInfo: nil, deliverImmediately: true)
            exit(0)
        }
        if !CommandLine.arguments.contains("--console") {
            let logs = library.appendingPathComponent("Logs/LogitechBatteryBridge", isDirectory: true)
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            let descriptor = open(logs.appendingPathComponent("bridge.log").path, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { fatalError("Cannot open log file") }
            dup2(descriptor, STDOUT_FILENO)
            dup2(descriptor, STDERR_FILENO)
            close(descriptor)
        }
    } catch { fatalError("Cannot prepare runtime: \(error)") }
}

setbuf(stdout, nil)
let once = CommandLine.arguments.contains("--once")
if !once { prepareRuntime() }
let application: NSApplication? = once ? nil : NSApplication.shared
application?.setActivationPolicy(.accessory)
let deviceNames = DeviceNames()
let dashboard: DashboardModel? = once ? nil : DashboardModel(names: deviceNames)
let hid = HIDPP()
hid.verbose = CommandLine.arguments.contains("--verbose")
let worker = DispatchQueue(label: "local.logitech.batterybridge.poll")
let publisher: PowerPublisher? = once ? nil : PowerPublisher(names: deviceNames)
let pollTimer = DispatchSource.makeTimerSource(queue: worker)
pollTimer.setEventHandler { poll() }
// Coalesce interface notifications from one USB insertion. All HID scanning
// stays on worker; the HID manager's notification queue never opens devices.
if !once {
    hid.onDevicesChanged = {
        worker.async {
            print("\(ISO8601DateFormatter().string(from: Date())) Receiver topology changed; refreshing connection")
            pollTimer.schedule(deadline: .now() + .milliseconds(300))
        }
    }
}
let removalMonitor: ReceiverRemovalMonitor? = once ? nil : ReceiverRemovalMonitor { ids in
    publisher?.removeConnections(ids)
    dashboard?.removeConnections(ids)
}
var signalSources: [DispatchSourceSignal] = []
for number in [SIGTERM, SIGINT] {
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
    source.setEventHandler {
        worker.async { pollTimer.cancel(); hid.close(); publisher?.close(); exit(0) }
    }
    source.resume()
    signalSources.append(source)
}

func poll() {
    if !once { DispatchQueue.main.async { dashboard?.beginRefresh() } }
    hid.rescan()
    var readings = hid.scanAll()
    if readings.isEmpty && !once {
        print("No response; retrying in two seconds")
        Thread.sleep(forTimeInterval: 2)
        hid.rescan()
        readings = hid.scanAll()
    }
    for device in readings {
        print("\(ISO8601DateFormatter().string(from: Date())) \(device.name): \(device.percent ?? -1)% \(device.state) id=\(device.id)")
    }
    if readings.isEmpty { print("No supported mouse answered; keeping last valid readings for up to five minutes") }
    if once { hid.close(); exit(readings.isEmpty ? 1 : 0) }
    publisher?.publish(readings)
    let completedReadings = readings
    let count = hid.deviceCount
    DispatchQueue.main.async { dashboard?.finishRefresh(completedReadings, receiverCount: count) }
    pollTimer.schedule(deadline: .now() + 60)
}
let dashboardController: DashboardController? = dashboard.map { model in
    DashboardController(model: model,
        background: CommandLine.arguments.contains("--background"),
        refresh: {
            model.beginRefresh()
            worker.async { pollTimer.schedule(deadline: .now()) }
        }, rename: { id, text in
            let name = try model.renameDevice(id, name: text)
            worker.async { publisher?.renameDevice(id, name: name) }
        }, quit: {
            worker.async {
                pollTimer.cancel()
                hid.close()
                publisher?.close()
                DispatchQueue.main.async { NSApp.reply(toApplicationShouldTerminate: true) }
            }
        })
}
application?.delegate = dashboardController
hid.start()
pollTimer.schedule(deadline: .now())
pollTimer.resume()
if let application { application.run() } else { dispatchMain() }
