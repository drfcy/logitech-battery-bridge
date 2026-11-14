var connected: Set<UInt64> = [101, 202, 303]
var nextHandle = 0
var liveHandles = Set<Int>()
var lastDetails: [String: Any] = [:]
func fakeCreate(_ p: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32 {
    nextHandle += 1
    liveHandles.insert(nextHandle)
    p.pointee = UnsafeMutableRawPointer(bitPattern: nextHandle)
    return 0
}
func fakeUpdate(_ p: UnsafeMutableRawPointer, _ details: CFDictionary) -> Int32 {
    lastDetails = details as! [String: Any]
    assert(liveHandles.contains(Int(bitPattern: p)))
    return 0
}
func fakeRelease(_ p: UnsafeMutableRawPointer) -> Int32 {
    assert(liveHandles.remove(Int(bitPattern: p)) != nil, "double release")
    return 0
}
func reading(_ id: String, _ connection: UInt64, _ state: ChargeState = .discharging) -> DeviceReading {
    DeviceReading(id: id, name: id, percent: 55, state: state, transport: .receiver, connectionID: connection)
}
let p = PowerPublisher(createFunction: fakeCreate, updateFunction: fakeUpdate,
    releaseFunction: fakeRelease, isConnected: { connected.contains($0) })
p.publish([reading("A", 101), reading("B", 101), reading("C", 202)], now: 0)
assert(liveHandles.count == 3)
p.publish([], now: 10)
assert(liveHandles.count == 3, "transient miss must preserve readings")
p.removeConnections([101])
assert(liveHandles.count == 1, "unplug must immediately remove both mice on that receiver")
p.publish([reading("A", 101), reading("B", 101), reading("C", 202)], now: 20)
assert(liveHandles.count == 1 && nextHandle == 3, "late scan cannot resurrect a removed connection")
p.publish([reading("A", 303, .charging)], now: 20)
assert(liveHandles.count == 2 && nextHandle == 4, "same mouse can reappear on a new connection")
assert(lastDetails["Is Charging"] as? Bool == true)
assert(lastDetails["Power Source State"] as? String == "AC Power")
p.publish([reading("A", 303, .full)], now: 20)
assert(lastDetails["Is Charging"] as? Bool == false)
assert(lastDetails["Is Charged"] as? Bool == true)
connected.remove(202)
p.publish([], now: 25)
assert(liveHandles.count == 1, "a missing termination event is caught by registry presence check")
p.publish([], now: 319)
assert(liveHandles.count == 1, "valid readings survive a brief miss")
p.publish([], now: 320)
assert(liveHandles.isEmpty, "stale reading must expire at five minutes")
p.close()
print("PASS: retention, receiver removal, multiple mice, stale scan race, reconnection, charging mapping, expiration")
