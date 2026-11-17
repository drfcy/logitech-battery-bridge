// GPL-3.0. Regression test: simulate receiver removal/rearrival with real
// IOHIDDevice handles without resetting USB or generating mouse input.
import Foundation
import IOKit
import IOKit.hid

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    print("PASS: \(message)")
}
func receiverSnapshot() -> Set<IOHIDDevice> {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
    IOHIDManagerSetDeviceMatching(manager, ["VendorID": 0x046d, "DeviceUsagePage": 0xff00] as CFDictionary)
    return (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
}
let initial = receiverSnapshot()
check(!initial.isEmpty, "Logitech receiver available for integration test")
var snapshot = initial
let hid = HIDPP()
hid.deviceSnapshotForTesting = { snapshot }
let notification = DispatchSemaphore(value: 0)
hid.onDevicesChanged = { notification.signal() }
hid.start()
check(notification.wait(timeout: .now() + 5) == .success, "HID manager delivers device notifications")
let initialIDs = hid.connectionIDs
check(hid.deviceCount == initialIDs.count && !initialIDs.isEmpty, "connected receivers tracked once")
for cycle in 1...3 {
    for _ in 0..<5 { hid.rescan() }
    check(hid.deviceCount == initialIDs.count, "cycle \(cycle): repeated rescan does not duplicate handles")
    snapshot = []
    hid.rescan()
    check(hid.deviceCount == 0, "cycle \(cycle): empty snapshot removes every old connection")
    // Give cancellation handlers time to close old handles before reopening.
    Thread.sleep(forTimeInterval: 0.1)
    snapshot = receiverSnapshot()
    hid.rescan()
    check(hid.connectionIDs == initialIDs, "cycle \(cycle): same receiver can be reopened")
    if case .success(let battery) = hid.readBattery() {
        check((0...100).contains(battery.percent), "cycle \(cycle): reopened connection returns battery data")
    } else {
        check(false, "cycle \(cycle): reopened connection returns battery data")
    }
}
hid.close()
check(hid.deviceCount == 0, "shutdown clears all handles")

// Stale readings from the removed USB identity must not overwrite the new one.
var creates = 0, updates = 0, releases = 0
var alive: Set<UInt64> = [111]
let publisher = PowerPublisher(createFunction: { output in
    creates += 1
    output.pointee = UnsafeMutableRawPointer(bitPattern: 0x1000 + creates)
    return 0
}, updateFunction: { _, _ in updates += 1; return 0 },
releaseFunction: { _ in releases += 1; return 0 }, isConnected: { alive.contains($0) })
func reading(_ connection: UInt64) -> DeviceReading {
    DeviceReading(id: "U:TEST", name: "Test Mouse", percent: 45, state: .discharging,
                  transport: .receiver, connectionID: connection)
}
publisher.publish([reading(111)], now: 0)
alive = []
publisher.removeConnections([111])
check(creates == 1 && releases == 1, "unplug withdraws the old battery source")
publisher.publish([reading(111)], now: 1)
check(updates == 1, "late old-connection reading is rejected")
alive = [222]
publisher.publish([reading(222)], now: 2)
check(creates == 2 && updates == 2, "replug publishes the same mouse on its new connection")
publisher.publish([reading(111)], now: 3)
check(updates == 2, "old connection cannot replace a reconnected mouse")
publisher.close()
check(releases == 2, "shutdown releases the reconnected battery source")
print("All reconnect regression checks passed.")

// The window must label retained readings and clear a removed connection.
let model = DashboardModel()
let origin = Date(timeIntervalSince1970: 1_000)
model.beginRefresh()
check(model.refreshing, "window marks an active scan")
model.finishRefresh([reading(111)], receiverCount: 1, now: origin, isConnected: { _ in true })
check(!model.refreshing && model.devices.count == 1 && model.currentIDs == ["U:TEST"], "window shows fresh battery data")
model.finishRefresh([], receiverCount: 1, now: origin.addingTimeInterval(60), isConnected: { _ in true })
check(model.devices.count == 1 && model.currentIDs.isEmpty, "window distinguishes retained data from fresh data")
model.finishRefresh([], receiverCount: 1, now: origin.addingTimeInterval(301), isConnected: { _ in true })
check(model.devices.isEmpty, "window expires retained battery data after five minutes")
model.finishRefresh([reading(111)], receiverCount: 1, now: origin, isConnected: { _ in true })
model.removeConnections([111])
check(model.devices.isEmpty && model.currentIDs.isEmpty && model.receiverCount == 0, "unplug immediately clears the window")
model.finishRefresh([reading(222)], receiverCount: 1, now: origin, isConnected: { _ in false })
check(model.devices.isEmpty, "window rejects a late reading from an absent connection")
print("All dashboard checks passed.")

let namesFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let namesURL = namesFolder.appendingPathComponent("device-names.json")
defer { try? FileManager.default.removeItem(at: namesFolder) }
let customNames = DeviceNames(url: namesURL)
try customNames.setAlias("  春阳的鼠标  ", for: "U:TEST")
check(DeviceNames(url: namesURL).displayName(for: reading(111)) == "春阳的鼠标", "custom Unicode name is trimmed and persists across reload")
check(reading(111).name == "Test Mouse", "custom name leaves the hardware name intact")
let namedModel = DashboardModel(names: customNames)
namedModel.finishRefresh([reading(111)], receiverCount: 1, now: origin, isConnected: { _ in true })
check(namedModel.displayName(namedModel.devices[0]) == "春阳的鼠标", "window loads the stored display name")
try namedModel.renameDevice("U:TEST", name: "我的鼠标")
check(namedModel.displayName(namedModel.devices[0]) == "我的鼠标", "window immediately reflects a saved name")
do {
    try customNames.setAlias("bad\nname", for: "U:TEST")
    check(false, "control characters are rejected")
} catch { check(customNames.displayName(for: reading(111)) == "我的鼠标", "invalid name preserves the saved name") }
try namedModel.renameDevice("U:TEST", name: " ")
check(namedModel.displayName(namedModel.devices[0]) == "Test Mouse" && DeviceNames(url: namesURL).snapshot.isEmpty,
      "blank name restores the original name and persists the reset")

var publishedNames: [String] = []
var renameReleases = 0
let namedPublisher = PowerPublisher(createFunction: { output in
    output.pointee = UnsafeMutableRawPointer(bitPattern: 0x2000); return 0
}, updateFunction: { _, details in
    let dictionary = details as! [String: Any]
    publishedNames.append(dictionary["Name"] as? String ?? "")
    check(dictionary["Current Capacity"] as? Int == 45, "rename preserves battery capacity")
    return 0
}, releaseFunction: { _ in renameReleases += 1; return 0 }, isConnected: { _ in true }, names: customNames)
try customNames.setAlias("我的鼠标", for: "U:TEST")
namedPublisher.publish([reading(111)], now: 0)
check(publishedNames.last == "我的鼠标", "system battery publication uses custom display name")
namedPublisher.renameDevice("U:TEST", name: "新名称")
check(publishedNames.last == "新名称", "system battery name changes without a new HID scan")
namedPublisher.publish([], now: 301)
check(renameReleases == 1, "renaming does not extend stale reading retention")
let renameCount = publishedNames.count
namedPublisher.renameDevice("U:TEST", name: "late")
check(publishedNames.count == renameCount, "renaming cannot recreate an expired battery source")
try Data("invalid json".utf8).write(to: namesURL)
let corruptNames = DeviceNames(url: namesURL)
do {
    try corruptNames.setAlias("new", for: "U:TEST")
    check(false, "corrupt settings are preserved")
} catch {
    let contents = try String(contentsOf: namesURL, encoding: .utf8)
    check(contents == "invalid json", "corrupt settings are not overwritten")
}
print("All naming checks passed.")
