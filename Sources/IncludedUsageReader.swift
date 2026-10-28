import WebKit

// Reads a personal plan's included usage from the dashboard overview in a short-lived web view of its own, so the
// main page can stay on the usage page for the CSV export. It shares the app's web session and keeps nothing.
@MainActor final class IncludedUsageReader: NSObject, WKNavigationDelegate {
    static let overview = URL(string: "https://cursor.com/dashboard")!
    static let spending = URL(string: "https://cursor.com/dashboard/spending")!
    private var reading: UsageSnapshot?
    private var web: WKWebView?
    private var completion: ((UsageSnapshot?) -> Void)?
    private var attempts = 0
    var isBusy: Bool { web != nil }

    func read(completion: @escaping (UsageSnapshot?) -> Void) {
        guard web == nil else { return }
        self.completion = completion; attempts = 0; reading = nil
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .default()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 900), configuration: configuration)
        view.navigationDelegate = self; web = view
        view.load(URLRequest(url: Self.overview))
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self, weak view] in if let self, let view, self.web === view { self.finish(self.reading) } }
    }
    func cancel() { web?.stopLoading(); web = nil; completion = nil }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Sent back to sign-in: the session is gone, there is nothing to read.
        guard DashboardLocation.destination(for: webView.url) != .signIn else { finish(nil); return }
        if reading != nil { attempts = 0; pollSpending() } else { poll() }
    }
    // A failure on the Spending page keeps the included reading already taken.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(reading) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(reading) }

    // The overview fills in after the page loads; look for the summary for up to twenty seconds.
    private func poll() {
        guard let web else { return }
        web.evaluateJavaScript(IncludedExtraction.script) { [weak self] result, _ in
            guard let self, self.web === web else { return }
            let extraction = result as? [String: Any] ?? [:]
            if let text = extraction["summary"] as? String, let reading = try? UsageParser.parseIncluded(text, plan: extraction["plan"] as? String) {
                // Then the Spending page, for money added beyond the included usage.
                self.reading = reading; web.load(URLRequest(url: Self.spending)); return
            }
            self.attempts += 1
            if self.attempts >= 20 { self.finish(nil); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.poll() }
        }
    }
    // The Spending page renders its amounts after loading; give it up to eight seconds, then keep the reading without them.
    private func pollSpending() {
        guard let web else { return }
        web.evaluateJavaScript(SpendingExtraction.script) { [weak self] result, _ in
            guard let self, self.web === web, var reading = self.reading else { return }
            if let text = result as? String, let money = UsageParser.parseOnDemand(text) {
                reading.onDemandSpentCents = money.spentCents; reading.onDemandLimitCents = money.limitCents; self.finish(reading); return
            }
            self.attempts += 1
            if self.attempts >= 8 || (result as? String)?.range(of: "Requires a paid plan", options: .caseInsensitive) != nil { self.finish(reading); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.pollSpending() }
        }
    }
    private func finish(_ reading: UsageSnapshot?) {
        let done = completion; completion = nil; web?.stopLoading(); web = nil
        done?(reading)
    }
}
