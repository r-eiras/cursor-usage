import Foundation

enum ProjectLinks {
    static let name = "Cursor Usage"
    static let repository = URL(string: "https://github.com/r-eiras/cursor-usage")!
    static let releases = repository.appendingPathComponent("releases")
    static let issues = repository.appendingPathComponent("issues/new")
    static let latestAPI = URL(string: "https://api.github.com/repos/r-eiras/cursor-usage/releases/latest")!
}

struct ReleaseVersion: Comparable {
    let major: Int, minor: Int, patch: Int
    init?(_ raw: String) {
        let text = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(pieces[0]), let minor = Int(pieces[1]), let patch = Int(pieces[2]) else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }
    static func < (a: Self, b: Self) -> Bool { (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch) }
}

enum ReleaseCheckResult: Equatable {
    case upToDate, noRelease, rateLimited, failed
    case available(version: String, url: URL)
}

enum ReleaseChecker {
    private struct Release: Decodable {
        let tag_name: String, html_url: URL
        let draft: Bool, prerelease: Bool
    }
    static func check(installedVersion: String, endpoint: URL = ProjectLinks.latestAPI, timeout: TimeInterval = 12) async -> ReleaseCheckResult {
        guard let current = ReleaseVersion(installedVersion) else { return .failed }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout; config.timeoutIntervalForResource = timeout
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CursorUsage/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { return .failed }
            if response.statusCode == 404 { return .noRelease }
            if [403, 429].contains(response.statusCode) { return .rateLimited }
            guard response.statusCode == 200, data.count <= 1_000_000,
                  let release = try? JSONDecoder().decode(Release.self, from: data),
                  !release.draft, !release.prerelease, let version = ReleaseVersion(release.tag_name),
                  release.html_url.scheme == "https", release.html_url.host == "github.com",
                  release.html_url.user == nil, release.html_url.password == nil,
                  release.html_url.port == nil,
                  release.html_url.path.hasPrefix("/r-eiras/cursor-usage/releases/tag/") else { return .failed }
            return version > current ? .available(version: String(release.tag_name.drop(while: { $0 == "v" })), url: release.html_url) : .upToDate
        } catch { return .failed }
    }
}
