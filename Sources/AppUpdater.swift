import CryptoKit
import Foundation
import Security

// In-place updates from this project's GitHub releases. A file the app downloads itself carries no quarantine
// attribute, so Gatekeeper does not reassess the ad hoc signature: the same reason install.sh uses curl. Every
// download is checked against the release manifest and the new bundle's own signature before it replaces anything.
struct AppUpdate: Equatable {
    let version: String
    var archiveName: String { "CursorUsage-\(version)-macOS-arm64.zip" }
    var archiveURL: URL { release.appendingPathComponent(archiveName) }
    var manifestURL: URL { release.appendingPathComponent("manifest.json") }
    private var release: URL { ProjectLinks.repository.appendingPathComponent("releases/download/v\(version)") }
}

enum AppUpdateError: Error, Equatable { case download, checksum, archive, bundle, notWritable, install }

struct AppUpdater {
    var fetch: (URL) async throws -> Data = AppUpdater.download
    var unzip: (URL, URL) throws -> Void = AppUpdater.ditto
    var bundleIdentifier = "local.cursorusage.CursorUsage"

    // Downloads, verifies and unpacks the release next to `folder`; returns the bundle ready to install.
    func prepare(_ update: AppUpdate, in folder: URL) async throws -> URL {
        guard let manifest = try? await fetch(update.manifestURL), let archive = try? await fetch(update.archiveURL) else { throw AppUpdateError.download }
        guard let expected = Self.digest(in: manifest, for: update.archiveName), expected == Self.sha256(archive) else { throw AppUpdateError.checksum }
        let zip = folder.appendingPathComponent(update.archiveName), staged = folder.appendingPathComponent("extracted")
        do { try archive.write(to: zip); try unzip(zip, staged) } catch { throw AppUpdateError.archive }
        let app = staged.appendingPathComponent("Cursor Usage.app")
        try validate(app, version: update.version)
        return app
    }
    func validate(_ app: URL, version: String) throws {
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleIdentifier, info["CFBundleShortVersionString"] as? String == version,
              Self.hasValidSignature(app), !Self.isQuarantined(app) else { throw AppUpdateError.bundle }
    }

    // Swaps the bundle at the installed location in one step, so a failure leaves the current version in place.
    static func install(_ staged: URL, over installed: URL) throws {
        guard FileManager.default.isWritableFile(atPath: installed.deletingLastPathComponent().path) else { throw AppUpdateError.notWritable }
        do { _ = try FileManager.default.replaceItemAt(installed, withItemAt: staged) } catch { throw AppUpdateError.install }
    }
    // Waits for this process to exit, then opens the new bundle. The path travels as an argument, never as script text.
    static func relaunchCommand(pid: Int32, app: URL, opener: String = "/usr/bin/open") -> [String] {
        ["/bin/sh", "-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; \(opener) \"$0\"", app.path]
    }

    static func digest(in manifest: Data, for archive: String) -> String? {
        ((try? JSONSerialization.jsonObject(with: manifest) as? [String: Any])?["archives"] as? [String: Any])?[archive] as? String
    }
    static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func hasValidSignature(_ app: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode), nil) == errSecSuccess
    }
    static func isQuarantined(_ app: URL) -> Bool { getxattr(app.path, "com.apple.quarantine", nil, 0, 0, 0) >= 0 }

    static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await client.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 50_000_000 else { throw AppUpdateError.download }
        return data
    }
    static func ditto(_ zip: URL, _ destination: URL) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zip.path, destination.path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppUpdateError.archive }
    }
    private static let client: URLSession = {
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 300
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }()
}
