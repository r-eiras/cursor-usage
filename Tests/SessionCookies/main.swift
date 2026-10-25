import AppKit
import WebKit
@MainActor final class CookieTest {
    let store = WKWebsiteDataStore.nonPersistent()
    func run() {
        let cookie = HTTPCookie(properties: [.domain: "example.test", .path: "/", .name: "synthetic-session", .value: "fictional"])!
        store.httpCookieStore.setCookie(cookie) {
            self.store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                self.store.httpCookieStore.getAllCookies { cookies in
                    guard cookies.isEmpty else { fatalError("Session cookies must be removed on logout") }
                    print("PASS: isolated WebKit session cookie cleanup"); exit(0)
                }
            }
        }
    }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared, test = CookieTest(); test.run()
    Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in fatalError("Cookie cleanup timed out") }
    app.run()
}
