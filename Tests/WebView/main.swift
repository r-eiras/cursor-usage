import AppKit
import WebKit

@MainActor
final class ExtractionTest: NSObject, WKNavigationDelegate {
    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    func run() {
        webView.navigationDelegate = self
        webView.loadHTMLString("""
        <html><body style="visibility:hidden">
        <div>Your <span>monthly</span> usage</div>
        <span>US$250.00</span><span>/</span><span>US$1,000.00</span>
        <p>Resets 1 Nov 2026</p>
        <script>const decoy = 'Your monthly usage $999 / $1000 Resets Dec 1, 2026';</script>
        </body></html>
        """, baseURL: nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.innerText") { value, error in
            guard error == nil, let text = value as? String, (try? UsageParser.parse(text)) == nil else {
                fatalError("The fixture must reproduce the failure of rendered-text extraction")
            }
            webView.evaluateJavaScript(QuotaExtraction.script) { value, error in
                guard error == nil, let result = value as? [String: Any], let summary = result["summary"] as? String,
                      let snapshot = try? UsageParser.parse(summary), snapshot.spentCents == 25000,
                      snapshot.limitCents == 100000 else {
                    fatalError("Hidden WebKit content must yield the quota while ignoring script decoys")
                }
                print("PASS: hidden WebKit extraction; split labels and values; scripts excluded")
                exit(0)
            }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let test = ExtractionTest()
    test.run()
    Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
        print("FAIL: WebKit fixture timed out")
        exit(1)
    }
    app.run()
}
