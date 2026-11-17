// GPL-3.0. Per-device display names, keyed by the HID++ stable identity.
import Foundation

final class DeviceNames {
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LogitechBatteryBridge/device-names.json")
    }
    private let url: URL
    private let lock = NSLock()
    private var aliases: [String: String] = [:]
    private var loadError: Error?

    init(url: URL = DeviceNames.defaultURL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do { aliases = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)) }
            catch { loadError = error }
        }
    }

    var snapshot: [String: String] {
        lock.lock(); defer { lock.unlock() }
        return aliases
    }

    func displayName(for device: DeviceReading) -> String {
        lock.lock(); defer { lock.unlock() }
        return aliases[device.id] ?? device.name
    }

    func setAlias(_ text: String, for id: String) throws {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 64, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw NSError(domain: "DeviceNames", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "名称最多 64 个字符，请勿使用换行或控制字符。"])
        }
        lock.lock(); defer { lock.unlock() }
        if let loadError {
            throw NSError(domain: "DeviceNames", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "无法读取名称设置文件，未覆盖原有设置。", NSUnderlyingErrorKey: loadError])
        }
        var updated = aliases
        if name.isEmpty { updated.removeValue(forKey: id) } else { updated[id] = name }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(updated)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        aliases = updated
    }
}
