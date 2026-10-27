import Foundation

// Account-specific data never crosses a disconnect/reconnect boundary.
// Logout archives local metrics so the action remains recoverable.
struct AccountSessionStorage {
    let folder: URL
    private var marker: URL { folder.appendingPathComponent(".signed-out") }
    var isSignedOut: Bool { FileManager.default.fileExists(atPath: marker.path) }
    func disconnect() throws {
        let files = ["history.json", "events.json", "alert-history.json", "models-seen.json"]
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let archive = folder.appendingPathComponent("account-history").appendingPathComponent(UUID().uuidString)
        var moved: [String] = []
        do {
            for name in files where manager.fileExists(atPath: folder.appendingPathComponent(name).path) {
                if moved.isEmpty { try manager.createDirectory(at: archive, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
                try manager.moveItem(at: folder.appendingPathComponent(name), to: archive.appendingPathComponent(name)); moved.append(name)
            }
            try Data("signed-out".utf8).write(to: marker, options: .atomic)
            try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: marker.path)
        } catch {
            for name in moved.reversed() { try? manager.moveItem(at: archive.appendingPathComponent(name), to: folder.appendingPathComponent(name)) }
            throw error
        }
    }
    func reconnect() throws {
        if isSignedOut { try FileManager.default.removeItem(at: marker) }
    }
}
