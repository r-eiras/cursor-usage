import Foundation

enum DashboardLocation {
    enum Destination: Equatable { case usage, dashboard, signIn }
    static func destination(for url: URL?) -> Destination {
        guard let url, url.scheme == "https",
              ["cursor.com", "www.cursor.com"].contains(url.host ?? "") else { return .signIn }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path == "dashboard/usage" { return .usage }
        if path == "dashboard" || path.hasPrefix("dashboard/") { return .dashboard }
        return .signIn
    }
}

struct UsageSnapshot: Codable {
    let spentCents: Int
    let limitCents: Int
    let resetDate: Date
    let observedAt: Date

    var remainingCents: Int { max(0, limitCents - spentCents) }
    var usedFraction: Double { Double(spentCents) / Double(limitCents) }

    struct Forecast {
        let dailyCents: Double
        let exhaustionDate: Date
    }

    static func forecast(history: [UsageSnapshot]) -> Forecast? {
        guard let latest = history.last else { return nil }
        let matching = history.filter {
            $0.resetDate == latest.resetDate && $0.limitCents == latest.limitCents &&
            latest.observedAt.timeIntervalSince($0.observedAt) >= 6 * 3600 &&
            latest.observedAt.timeIntervalSince($0.observedAt) <= 7 * 86400 &&
            $0.spentCents < latest.spentCents
        }
        guard let first = matching.first else { return nil }
        let seconds = latest.observedAt.timeIntervalSince(first.observedAt)
        let rate = Double(latest.spentCents - first.spentCents) / seconds
        return Forecast(dailyCents: rate * 86400,
                        exhaustionDate: latest.observedAt.addingTimeInterval(Double(latest.remainingCents) / rate))
    }
}

enum UsageParser {
    enum ParseError: Error { case missingQuota, invalidQuota, missingReset }

    static func parse(_ text: String, at date: Date = Date()) throws -> UsageSnapshot {
        let pattern = #"Your\s+monthly\s+usage\s*(?:US\s*)?\$\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*/\s*(?:US\s*)?\$\s*([0-9,]+(?:\.[0-9]{1,2})?)"#
        guard let amounts = groups(pattern, text) else { throw ParseError.missingQuota }
        func cents(_ value: String) -> Int? {
            guard let number = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            return NSDecimalNumber(decimal: number * 100).intValue
        }
        guard let spent = cents(amounts[0]), let limit = cents(amounts[1]), limit > 0 else {
            throw ParseError.invalidQuota
        }
        guard let resetText = groups(#"Resets\s+([A-Za-z]+\s+\d{1,2},?\s*\d{4}|\d{1,2}\s+[A-Za-z]+\s+\d{4})"#, text)?.first else {
            throw ParseError.missingReset
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        let reset = ["MMM d, yyyy", "d MMM yyyy", "MMM d yyyy"].compactMap { format -> Date? in
            formatter.dateFormat = format
            return formatter.date(from: resetText)
        }.first
        guard let reset else { throw ParseError.missingReset }
        return UsageSnapshot(spentCents: spent, limitCents: limit, resetDate: reset, observedAt: date)
    }

    private static func groups(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap {
            Range(match.range(at: $0), in: text).map { String(text[$0]) }
        }
    }
}


enum QuotaExtraction {
    static let script = #"""
        (() => {
          const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
            acceptNode: node => node.parentElement.closest('script,style,noscript,template') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
          });
          const parts = [];
          while (walker.nextNode()) parts.push(walker.currentNode.textContent);
          const text = parts.join(' ');
          const block = text.match(/Your\s+monthly\s+usage[\s\S]{0,180}?Resets[\s\S]{0,50}/i);
          return { summary: block ? block[0] : '', quotaFound: !!block, ready: document.readyState };
        })()
        """#
}
