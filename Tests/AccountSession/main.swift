import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
for name in ["history.json", "events.json", "alert-history.json", "preferences.json"] { try Data("synthetic".utf8).write(to: root.appendingPathComponent(name)) }
let storage = AccountSessionStorage(folder: root)
check(!storage.isSignedOut, "Existing installations remain connected")
try storage.disconnect()
check(storage.isSignedOut && FileManager.default.fileExists(atPath: root.appendingPathComponent("preferences.json").path), "Disconnect persists independently of settings")
check(!FileManager.default.fileExists(atPath: root.appendingPathComponent("history.json").path) && !FileManager.default.fileExists(atPath: root.appendingPathComponent("events.json").path), "Old metrics cannot load into a new account")
let archives = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("account-history"), includingPropertiesForKeys: nil)
check(archives.count == 1 && (try? Data(contentsOf: archives[0].appendingPathComponent("history.json"))) == Data("synthetic".utf8), "Previous observations remain recoverable in a private archive")
try storage.disconnect(); try storage.reconnect(); check(!storage.isSignedOut, "Repeated disconnect and explicit reconnection are safe")
let blocked = root.appendingPathComponent("failure")
try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
try Data("block".utf8).write(to: blocked.appendingPathComponent("account-history"))
try Data("keep".utf8).write(to: blocked.appendingPathComponent("history.json"))
var failed = false
do { try AccountSessionStorage(folder: blocked).disconnect() } catch { failed = true }
check(failed && !AccountSessionStorage(folder: blocked).isSignedOut && FileManager.default.fileExists(atPath: blocked.appendingPathComponent("history.json").path), "Archive failure keeps active metrics and does not pretend logout succeeded")
print("PASS: account isolation, recoverable logout, persistence and archive failures")
