import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
func run(_ tool: String, _ arguments: [String]) { let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = arguments; p.standardError = FileHandle.nullDevice; try! p.run(); p.waitUntilExit(); check(p.terminationStatus == 0, "\(tool) failed") }
let root = FileManager.default.temporaryDirectory.appendingPathComponent("updater \(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { run("/bin/chmod", ["-R", "u+w", root.path]); try? FileManager.default.removeItem(at: root) }

// A signed fixture bundle: Apple's `true` binary re-signed ad hoc, like the project's releases.
func bundle(_ name: String, id: String = "local.cursorusage.CursorUsage", version: String) -> URL {
    let app = root.appendingPathComponent(name).appendingPathComponent("Cursor Usage.app")
    try! FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    try! FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: app.appendingPathComponent("Contents/MacOS/CursorUsage"))
    (["CFBundleExecutable": "CursorUsage", "CFBundleIdentifier": id, "CFBundleShortVersionString": version, "CFBundlePackageType": "APPL"] as NSDictionary).write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true)
    run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
    return app
}
func zip(_ app: URL) -> Data {
    let file = app.deletingLastPathComponent().appendingPathComponent("archive.zip")
    run("/usr/bin/ditto", ["-ck", "--keepParent", app.path, file.path]); return try! Data(contentsOf: file)
}
let update = AppUpdate(version: "9.1.0")
func manifest(_ archive: Data, name: String = update.archiveName) -> Data { try! JSONSerialization.data(withJSONObject: ["archives": [name: AppUpdater.sha256(archive)]]) }
func updater(_ files: [URL: Data], unzip: ((URL, URL) throws -> Void)? = nil) -> AppUpdater {
    var value = AppUpdater(fetch: { url in guard let data = files[url] else { throw URLError(.fileDoesNotExist) }; return data })
    if let unzip { value.unzip = unzip }
    return value
}
func failure(_ work: () async throws -> URL) async -> AppUpdateError? { do { _ = try await work(); return nil } catch { return error as? AppUpdateError } }
func stage(_ name: String) -> URL { let url = root.appendingPathComponent("stage-\(name)"); try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }

check(update.archiveURL.absoluteString == "https://github.com/r-eiras/cursor-usage/releases/download/v9.1.0/CursorUsage-9.1.0-macOS-arm64.zip", "Download the app ZIP from this project's release")
check(update.manifestURL.absoluteString == "https://github.com/r-eiras/cursor-usage/releases/download/v9.1.0/manifest.json", "Verify against the same release's manifest")

let good = zip(bundle("good", version: "9.1.0"))
let ready = try await updater([update.archiveURL: good, update.manifestURL: manifest(good)]).prepare(update, in: stage("good"))
check(FileManager.default.fileExists(atPath: ready.appendingPathComponent("Contents/MacOS/CursorUsage").path), "A verified release is unpacked and ready")
check(AppUpdater.hasValidSignature(ready) && !AppUpdater.isQuarantined(ready), "The staged copy keeps a valid signature and no quarantine")

let checksum = await failure { try await updater([update.archiveURL: good, update.manifestURL: manifest(Data("other".utf8))]).prepare(update, in: stage("checksum")) }
check(checksum == .checksum, "Reject an archive that does not match the manifest")
let unlisted = await failure { try await updater([update.archiveURL: good, update.manifestURL: manifest(good, name: "other.zip")]).prepare(update, in: stage("unlisted")) }
check(unlisted == .checksum, "Reject an archive the manifest does not list")
let offline = await failure { try await updater([:]).prepare(update, in: stage("offline")) }
check(offline == .download, "A failed download changes nothing")
let foreign = zip(bundle("foreign", id: "com.example.other", version: "9.1.0"))
let foreignResult = await failure { try await updater([update.archiveURL: foreign, update.manifestURL: manifest(foreign)]).prepare(update, in: stage("foreign")) }
check(foreignResult == .bundle, "Never install another app")
let older = zip(bundle("older", version: "9.0.0"))
let olderResult = await failure { try await updater([update.archiveURL: older, update.manifestURL: manifest(older)]).prepare(update, in: stage("older")) }
check(olderResult == .bundle, "Install only the version the release announced")
let tamperedApp = bundle("tampered", version: "9.1.0")
try Data("changed after signing".utf8).write(to: tamperedApp.appendingPathComponent("Contents/MacOS/CursorUsage"))
let tampered = zip(tamperedApp)
let tamperedResult = await failure { try await updater([update.archiveURL: tampered, update.manifestURL: manifest(tampered)]).prepare(update, in: stage("tampered")) }
check(tamperedResult == .bundle, "Reject a bundle whose signature no longer matches")
let quarantinedResult = await failure {
    try await updater([update.archiveURL: good, update.manifestURL: manifest(good)], unzip: { zip, destination in
        try AppUpdater.ditto(zip, destination)
        run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0081;00000000;Safari;", destination.appendingPathComponent("Cursor Usage.app").path])
    }).prepare(update, in: stage("quarantined"))
}
check(quarantinedResult == .bundle, "Refuse a quarantined copy instead of stripping the attribute")

let installed = bundle("installed", version: "9.0.0")
try AppUpdater.install(ready, over: installed)
let installedVersion = NSDictionary(contentsOf: installed.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
check(installedVersion == "9.1.0" && AppUpdater.hasValidSignature(installed), "The new version replaces the bundle at the installed location")
check(!FileManager.default.fileExists(atPath: ready.path), "The staged copy is consumed by the swap")
let locked = bundle("locked", version: "9.0.0"), lockedReady = bundle("locked-ready", version: "9.1.0")
run("/bin/chmod", ["a-w", locked.deletingLastPathComponent().path])
var lockedError: AppUpdateError?
do { try AppUpdater.install(lockedReady, over: locked) } catch { lockedError = error as? AppUpdateError }
let lockedVersion = NSDictionary(contentsOf: locked.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
check(lockedError == .notWritable && lockedVersion == "9.0.0", "Without write access the current version stays untouched")

// The relaunch helper waits for the app to exit before reopening it; `touch` stands in for `open`.
let sleeper = Process(); sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep"); sleeper.arguments = ["1"]; try sleeper.run()
let marker = root.appendingPathComponent("relaunched app")
let helper = Process(); let command = AppUpdater.relaunchCommand(pid: sleeper.processIdentifier, app: marker, opener: "/usr/bin/touch")
helper.executableURL = URL(fileURLWithPath: command[0]); helper.arguments = Array(command.dropFirst()); try helper.run()
try await Task.sleep(for: .milliseconds(400))
check(!FileManager.default.fileExists(atPath: marker.path), "Do not reopen while the old process is still running")
helper.waitUntilExit()
check(FileManager.default.fileExists(atPath: marker.path) && !sleeper.isRunning, "Reopen the app, path with spaces intact, once the old process exits")
print("PASS: in-place update download checks, signature, quarantine refusal, atomic swap and relaunch")
