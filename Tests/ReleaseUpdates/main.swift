import Foundation
func check(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
check(ReleaseVersion("v1.10.0")! > ReleaseVersion("1.9.9")!, "Versions compare numerically")
check(ReleaseVersion("1.2.3-beta") == nil && ReleaseVersion("broken") == nil, "Unsupported release tags never claim an update")
check(ProjectLinks.repository.host == "github.com" && ProjectLinks.repository.path == "/r-eiras/cursor-usage", "Links target the personal project")
let base = CommandLine.arguments.dropFirst().first ?? "https://api.github.com/repos/r-eiras/cursor-usage/releases/latest"
Task {
    if CommandLine.arguments.contains("--live") {
        let result = await ReleaseChecker.check(installedVersion: "3.1.4")
        check(result == .upToDate, "The published release is readable without account credentials")
        print("PASS: live public release check without GitHub credentials"); exit(0)
    }
    func run(_ scenario: String, installed: String = "3.1.4", timeout: TimeInterval = 3) async -> ReleaseCheckResult {
        var parts = URLComponents(string: base)!
        parts.queryItems = [URLQueryItem(name: "scenario", value: scenario)]
        return await ReleaseChecker.check(installedVersion: installed, endpoint: parts.url!, timeout: timeout)
    }
    check(await run("current") == .upToDate, "Equal versions are current")
    check(await run("current", installed: "3.2.0") == .upToDate, "A development build is never offered a downgrade")
    check(await run("available") == .available(version: "3.2.0", url: URL(string: "https://github.com/r-eiras/cursor-usage/releases/tag/v3.2.0")!), "A newer version links to its own project release")
    check(await run("missing") == .noRelease, "404 means no public release")
    check(await run("rate") == .rateLimited, "Rate limits are not reported as up to date")
    for scenario in ["server", "invalid", "foreign", "draft"] {
        check(await run(scenario) == .failed, "Bad responses never become a current-version claim")
    }
    check(await run("slow", timeout: 0.2) == .failed, "A slow server respects the timeout")
    print("PASS: real URLSession release checks against local HTTP simulation"); exit(0)
}
dispatchMain()
