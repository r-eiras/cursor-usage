import Foundation

enum DashboardLocation {
    enum Destination: Equatable { case usage, dashboard, authRedirect, signIn }
    static func destination(for url: URL?) -> Destination {
        guard let url, url.scheme == "https",
              ["cursor.com", "www.cursor.com"].contains(url.host ?? "") else { return .signIn }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path == "dashboard/usage" { return .usage }
        // Cursor's own auth steps (session bootstrap, refresh) pass through on the way back to the dashboard.
        if path.hasPrefix("api/auth/") { return .authRedirect }
        if path == "dashboard" || path.hasPrefix("dashboard/") { return .dashboard }
        return .signIn
    }
}

// Corporate accounts show a dollar quota on the usage page; personal plans (Free, Plus, Premium…) only show the share
// of their included usage on the dashboard overview, so a reading is one or the other.
enum QuotaKind: String, Codable { case dollars, includedPercent }

struct UsageSnapshot: Codable {
    let spentCents: Int
    let limitCents: Int
    let resetDate: Date
    let observedAt: Date
    // nil on readings saved before personal accounts were supported: those are dollar readings.
    var kind: QuotaKind? = nil
    var plan: String? = nil
    // Money a personal plan spends beyond its included usage, and the limit set for it, from the Spending page.
    var onDemandSpentCents: Int? = nil
    var onDemandLimitCents: Int? = nil
    // A personal reading stores the share used in hundredths of a percent, out of 10,000.
    var isIncludedPercent: Bool { kind == .includedPercent }

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

    // "Your included usage 37% used Resets 4 Nov 2026", from the dashboard overview of a personal plan.
    static func parseIncluded(_ text: String, plan: String? = nil, at date: Date = Date()) throws -> UsageSnapshot {
        guard let match = groups(#"Your\s+included\s+usage\s*([0-9]+(?:[.,][0-9]+)?)\s*%\s*used[\s\S]{0,80}?Resets\s+([A-Za-z]+\s+\d{1,2},?\s*\d{4}|\d{1,2}\s+[A-Za-z]+\s+\d{4})"#, text),
              let percent = Double(match[0].replacingOccurrences(of: ",", with: ".")), percent >= 0 else { throw ParseError.missingQuota }
        guard let reset = resetDate(match[1]) else { throw ParseError.missingReset }
        return UsageSnapshot(spentCents: Int((percent * 100).rounded()), limitCents: 10_000, resetDate: reset, observedAt: date, kind: .includedPercent,
                             plan: plan.flatMap { $0.isEmpty ? nil : $0 })
    }
    // "On-Demand Usage … $12.40 / $50.00" (or "of"), only when that section shows both amounts; a free plan shows none.
    static func parseOnDemand(_ text: String) -> (spentCents: Int, limitCents: Int)? {
        guard let start = text.range(of: "On-Demand Usage", options: .caseInsensitive) else { return nil }
        let section = String(text[start.lowerBound...].prefix(400))
        guard let match = groups(#"(?:US\s*)?\$\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:/|of)\s*(?:US\s*)?\$\s*([0-9,]+(?:\.[0-9]{1,2})?)"#, section) else { return nil }
        func cents(_ value: String) -> Int? { Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")).map { NSDecimalNumber(decimal: $0 * 100).intValue } }
        guard let spent = cents(match[0]), let limit = cents(match[1]), limit > 0 else { return nil }
        return (spent, limit)
    }
    private static func resetDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.isLenient = false
        return ["MMM d, yyyy", "d MMM yyyy", "MMM d yyyy"].lazy.compactMap { format -> Date? in formatter.dateFormat = format; return formatter.date(from: text) }.first
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
          // A usage page without the dollar summary belongs to a personal plan; its quota is on the overview.
          const usagePage = /Export\s+CSV|Total\s+tokens/i.test(text);
          return { summary: block ? block[0] : '', quotaFound: !!block, usagePage, ready: document.readyState };
        })()
        """#
}

// The Spending page's text, for a personal plan's on-demand money.
enum SpendingExtraction {
    static let script = #"(() => document.body.innerText || '')()"#
}

// The dashboard overview of a personal plan: its included-usage share, reset date and plan name.
enum IncludedExtraction {
    static let script = #"""
        (() => {
          const text = document.body.innerText || '';
          const block = text.match(/Your\s+included\s+usage[\s\S]{0,80}?Resets\s+[^\n]{0,30}/i);
          const lines = text.split('\n').map(line => line.trim()).filter(Boolean);
          const overview = lines.indexOf('Overview');
          const candidate = overview > 0 ? lines[overview - 1] : '';
          const plan = /^(Free|Hobby|Plus|Premium|Super|Ultra|Pro\+?)$/i.test(candidate) ? candidate : '';
          return { summary: block ? block[0] : '', plan, ready: document.readyState };
        })()
        """#
}
