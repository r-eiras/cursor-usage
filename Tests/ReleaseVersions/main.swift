import Foundation
func check(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
check(ReleaseVersion("v1.10.0")! > ReleaseVersion("1.9.9")!, "Versions compare numerically")
check(ReleaseVersion("1.2.3-beta") == nil && ReleaseVersion("broken") == nil, "Unsupported release tags never claim an update")
check(ProjectLinks.repository.host == "github.com" && ProjectLinks.repository.path == "/r-eiras/cursor-usage", "Links target the personal project")
print("PASS: numeric versions and official project links")
