import Foundation
import WebKit

@MainActor
final class UsageExporter: NSObject, WKDownloadDelegate {
    weak var webView: WKWebView?
    var onDataset: ((UsageDataset) -> Void)?
    var onFailure: ((String) -> Void)?
    private var coverage: DateInterval?
    private var cancellationGeneration = 0
    private var pendingDownloads = 0
    private var downloads: [ObjectIdentifier: (WKDownload, URL, DateInterval)] = [:]
    var isBusy: Bool { pendingDownloads > 0 || !downloads.isEmpty }

    func cancelAll() {
        cancellationGeneration += 1; pendingDownloads = 0
        let active = Array(downloads.values); downloads.removeAll()
        for (download, file, _) in active {
            download.cancel { _ in }
            try? FileManager.default.removeItem(at: file)
        }
    }
    func prepare(coverage: DateInterval) { self.coverage = coverage }
    static func isExport(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && ["cursor.com", "www.cursor.com"].contains(url.host ?? "") && url.path == "/api/dashboard/export-usage-events-csv"
    }
    @discardableResult func capture(_ request: URLRequest) -> Bool {
        guard Self.isExport(request.url), let webView, coverage != nil,
              let parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false),
              let startRaw = parts.queryItems?.first(where: { $0.name == "startDate" })?.value,
              let endRaw = parts.queryItems?.first(where: { $0.name == "endDate" })?.value,
              let start = Double(startRaw), let end = Double(endRaw), end >= start else { return false }
        let actualCoverage = DateInterval(start: Date(timeIntervalSince1970: start / 1000), end: Date(timeIntervalSince1970: (end + 1) / 1000))
        guard !isBusy else { return true }
        let generation = cancellationGeneration; pendingDownloads += 1
        webView.startDownload(using: request) { [weak self] download in
            guard let self, self.cancellationGeneration == generation else { download.cancel { _ in }; return }
            self.pendingDownloads = max(0, self.pendingDownloads - 1)
            self.register(download, coverage: actualCoverage)
        }
        return true
    }
    private func register(_ download: WKDownload, coverage: DateInterval) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ai-quota-\(UUID().uuidString).csv")
        downloads[ObjectIdentifier(download)] = (download, file, coverage)
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        guard let entry = downloads[ObjectIdentifier(download)] else { completionHandler(nil); return }
        guard response.mimeType != "text/html" else {
            downloads.removeValue(forKey: ObjectIdentifier(download)); completionHandler(nil)
            onFailure?(L("Reconecte a conta para baixar o histórico.", "Reconnect your account to download history.")); return
        }
        completionHandler(entry.1)
    }
    func downloadDidFinish(_ download: WKDownload) {
        let identifier = ObjectIdentifier(download)
        guard let (_, file, coverage) = downloads[identifier] else { return }
        let unknownModelName = L("Modelo não informado", "Unreported model")
        // Keep the download busy until parsing completes. CSV parsing must not block AppKit.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result {
                defer { try? FileManager.default.removeItem(at: file) }
                let text = try String(contentsOf: file, encoding: .utf8)
                return try UsageCSV.parse(text, coverage: coverage, fetchedAt: Date(), unknownModelName: unknownModelName)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.downloads.removeValue(forKey: identifier) != nil else { return }
                switch result {
                case .success(let dataset): self.onDataset?(dataset)
                case .failure(UsageCSV.ImportError.multipleAccounts):
                    self.onFailure?(L("O CSV contém várias contas. O resumo individual foi preservado.", "The CSV contains multiple accounts. The individual summary was preserved."))
                case .failure:
                    self.onFailure?(L("Formato do histórico não reconhecido. Tente atualizar.", "History format not recognized. Try refreshing."))
                }
            }
        }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let entry = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        try? FileManager.default.removeItem(at: entry.1)
        onFailure?(L("Não foi possível baixar o histórico. Tente atualizar.", "Could not download the history. Try refreshing."))
    }

    static let triggerScript = #"""
    (() => {
      const button = Array.from(document.querySelectorAll('button')).find(item => item.textContent.trim() === 'Export CSV' && !item.disabled);
      if (!button) return false;
      button.click();
      return true;
    })()
    """#
    static let linkScript = #"""
    (() => {
      const field = Array.from(document.querySelectorAll('input')).find(item => item.value.includes('/api/dashboard/export-usage-events-csv?'));
      return field ? field.value : '';
    })()
    """#
}
