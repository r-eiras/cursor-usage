import Foundation
import CryptoKit

struct UsageEvent: Codable {
    let date: Date
    let model: String
    let kind: String
    let costMicros: Int64
    let inputTokens: Int64?
    let cacheWriteTokens: Int64?
    let cacheReadTokens: Int64?
    let outputTokens: Int64?
    let totalTokens: Int64?
}

struct UsageDataset: Codable {
    let events: [UsageEvent]
    let coverageStart: Date
    let coverageEnd: Date
    let fetchedAt: Date
    let accountDigest: String
}

enum UsageCSV {
    enum ImportError: Error { case malformedCSV, missingColumns, invalidRow(Int), multipleAccounts }

    static func parse(_ text: String, coverage: DateInterval, fetchedAt: Date, unknownModelName: String = "Unreported model") throws -> UsageDataset {
        let rows = try readRows(text.replacingOccurrences(of: "\u{feff}", with: ""))
        guard let header = rows.first else { throw ImportError.missingColumns }
        let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard Set(names).count == names.count else { throw ImportError.missingColumns }
        let required = ["Date", "User", "Model", "Cost", "Total Tokens", "Kind"]
        guard required.allSatisfy(names.contains) else { throw ImportError.missingColumns }
        let indices = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainISO = ISO8601DateFormatter()
        var accounts = Set<String>()
        var events: [UsageEvent] = []
        for (index, row) in rows.dropFirst().enumerated() {
            guard row.count == header.count else { throw ImportError.invalidRow(index + 2) }
            func value(_ key: String) -> String { indices[key].map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) } ?? "" }
            let account = value("User").lowercased()
            if !account.isEmpty { accounts.insert(account) }
            guard accounts.count <= 1 else { throw ImportError.multipleAccounts }
            guard let date = iso.date(from: value("Date")) ?? plainISO.date(from: value("Date")) else {
                throw ImportError.invalidRow(index + 2)
            }
            let cost: Int64
            if value("Cost").lowercased() == "free" { cost = 0 }
            else {
                guard let decimal = Decimal(string: value("Cost"), locale: Locale(identifier: "en_US_POSIX")), decimal >= 0 else {
                    throw ImportError.invalidRow(index + 2)
                }
                cost = NSDecimalNumber(decimal: decimal * 1_000_000).int64Value
            }
            func tokens(_ key: String) throws -> Int64? {
                let raw = value(key)
                if raw.isEmpty || raw == "-" { return nil }
                guard let count = Int64(raw), count >= 0 else { throw ImportError.invalidRow(index + 2) }
                return count
            }
            events.append(UsageEvent(date: date, model: value("Model").isEmpty ? unknownModelName : value("Model"),
                                     kind: value("Kind"), costMicros: cost,
                                     inputTokens: try tokens("Input (w/o Cache Write)"),
                                     cacheWriteTokens: try tokens("Input (w/ Cache Write)"),
                                     cacheReadTokens: try tokens("Cache Read"), outputTokens: try tokens("Output Tokens"),
                                     totalTokens: try tokens("Total Tokens")))
        }
        let digest = SHA256.hash(data: Data((accounts.first ?? "").utf8)).map { String(format: "%02x", $0) }.joined()
        return UsageDataset(events: events, coverageStart: coverage.start, coverageEnd: coverage.end,
                            fetchedAt: fetchedAt, accountDigest: digest)
    }

    private static func readRows(_ text: String) throws -> [[String]] {
        let characters = Array(text)
        var rows: [[String]] = [], row: [String] = []
        var cell = "", quoted = false, index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted && index + 1 < characters.count && characters[index + 1] == "\"" {
                    cell.append("\""); index += 1
                } else if quoted || cell.isEmpty { quoted.toggle() }
                else { throw ImportError.malformedCSV }
            } else if character == "," && !quoted {
                row.append(cell); cell = ""
            } else if (character == "\n" || character == "\r" || character == "\r\n") && !quoted {
                row.append(cell); cell = ""
                if !row.allSatisfy({ $0.isEmpty }) { rows.append(row) }
                row = []
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" { index += 1 }
            } else { cell.append(character) }
            index += 1
        }
        guard !quoted else { throw ImportError.malformedCSV }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows
    }
}

enum UsagePeriod: String, Codable, CaseIterable {
    case today, week, last3, last7, month
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "custom" { self = .month; return }
        guard let period = Self(rawValue: raw) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown usage period") }
        self = period
    }
    var title: String {
        switch self {
        case .today: return L("Hoje", "Today")
        case .week: return L("Esta semana", "This week")
        case .last3: return L("Últimos 3 dias", "Last 3 days")
        case .last7: return L("Últimos 7 dias", "Last 7 days")
        case .month: return L("Mês corrente", "Current month")
        }
    }
}

struct PeriodSelection: Codable {
    var preset: UsagePeriod = .month

    func interval(now: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        let start: Date
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        switch preset {
        case .today: start = today
        case .week:
            let offset = (calendar.component(.weekday, from: today) + 5) % 7
            start = calendar.date(byAdding: .day, value: -offset, to: today)!
        case .last3: start = calendar.date(byAdding: .day, value: -2, to: today)!
        case .last7: start = calendar.date(byAdding: .day, value: -6, to: today)!
        case .month: start = calendar.dateInterval(of: .month, for: now)!.start

        }
        guard start < end, start <= now else { return nil }
        return DateInterval(start: start, end: end)
    }
}

struct ModelUsage {
    let model: String
    var costMicros: Int64 = 0
    var tokens: Int64 = 0
    var missingTokenEvents = 0
    var events = 0
    var input: Int64 = 0
    var cacheWrite: Int64 = 0
    var cacheRead: Int64 = 0
    var output: Int64 = 0
}

// Weekdays only, for users who keep weekends out of their quota; which days are the weekend follows the region.
enum Workdays {
    // Days from the start of `from`'s day up to `to` that count: all of them, or only weekdays.
    static func count(from: Date, to: Date, excludeWeekends: Bool, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: from), result = 0
        while day < to {
            if !excludeWeekends || !calendar.isDateInWeekend(day) { result += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
    // Seconds between two moments that count: all of them, or only those on weekdays.
    static func seconds(from: Date, to: Date, excludeWeekends: Bool, calendar: Calendar) -> TimeInterval {
        guard excludeWeekends else { return max(0, to.timeIntervalSince(from)) }
        var day = calendar.startOfDay(for: from), result: TimeInterval = 0
        while day < to {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            if !calendar.isDateInWeekend(day) { result += max(0, min(next, to).timeIntervalSince(max(day, from))) }
            day = next
        }
        return result
    }
}

struct DailyUsage { let date: Date; let costMicros: Int64 }
struct UsageProjection {
    let dailyMicros: Double
    let safeDailyMicros: Double
    let remainingDays: Int
    let projectedMonthMicros: Double?
    let monthEnd: Date
    let idealDailyMicros: Double
}
struct AnalyticsReport {
    let interval: DateInterval
    let costMicros: Int64
    let tokens: Int64
    let missingTokenEvents: Int
    let models: [ModelUsage]
    let daily: [DailyUsage]
    let projection: UsageProjection?
    let eventCount: Int
}

enum AnalyticsEngine {
    static func report(dataset: UsageDataset, selection: PeriodSelection, quota: UsageSnapshot?, now: Date, calendar: Calendar = .current, excludeWeekends: Bool = false) -> AnalyticsReport? {
        guard let interval = selection.interval(now: now, calendar: calendar),
              dataset.coverageStart <= interval.start, dataset.coverageEnd >= min(now, interval.end) else { return nil }
        let rows = dataset.events.filter { $0.date >= interval.start && $0.date < interval.end && $0.date <= now }
        var models: [String: ModelUsage] = [:]
        var daily: [Date: Int64] = [:]
        for row in rows {
            var model = models[row.model] ?? ModelUsage(model: row.model)
            model.costMicros += row.costMicros; model.events += 1
            if let tokens = row.totalTokens { model.tokens += tokens } else { model.missingTokenEvents += 1 }
            model.input += row.inputTokens ?? 0; model.cacheWrite += row.cacheWriteTokens ?? 0
            model.cacheRead += row.cacheReadTokens ?? 0; model.output += row.outputTokens ?? 0
            models[row.model] = model
            daily[calendar.startOfDay(for: row.date), default: 0] += row.costMicros
        }
        var days: [DailyUsage] = []
        var day = interval.start
        while day < interval.end && day <= now {
            days.append(DailyUsage(date: day, costMicros: daily[day] ?? 0))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let cost = rows.reduce(Int64(0)) { $0 + $1.costMicros }
        var projection: UsageProjection?
        if let quota, !quota.isIncludedPercent {
            // With weekends excluded, every figure here is per weekday: weekend spending still counts, spread over weekdays.
            let exposureDays = max(1.0 / 24, Workdays.seconds(from: interval.start, to: min(now, interval.end), excludeWeekends: excludeWeekends, calendar: calendar) / 86400)
            let rate = Double(cost) / exposureDays
            var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
            let resetParts = utc.dateComponents([.year, .month, .day], from: quota.resetDate)
            let reset = calendar.date(from: resetParts)!
            let remaining = Workdays.count(from: now, to: reset, excludeWeekends: excludeWeekends, calendar: calendar)
            let month = calendar.dateInterval(of: .month, for: now)!
            let monthCovered = dataset.coverageStart <= month.start && dataset.coverageEnd >= now
            let monthCost = dataset.events.filter { $0.date >= month.start && $0.date <= now }.reduce(Int64(0)) { $0 + $1.costMicros }
            let monthDays = max(1, Workdays.count(from: month.start, to: month.end, excludeWeekends: excludeWeekends, calendar: calendar))
            projection = UsageProjection(dailyMicros: rate,
                safeDailyMicros: remaining > 0 ? Double(quota.remainingCents) * 10_000 / Double(remaining) : 0,
                remainingDays: remaining,
                projectedMonthMicros: monthCovered ? Double(monthCost) + rate * Workdays.seconds(from: now, to: month.end, excludeWeekends: excludeWeekends, calendar: calendar) / 86400 : nil,
                monthEnd: month.end.addingTimeInterval(-1), idealDailyMicros: Double(quota.limitCents) * 10_000 / Double(monthDays))
        }
        return AnalyticsReport(interval: interval, costMicros: cost,
            tokens: rows.compactMap(\.totalTokens).reduce(0, +), missingTokenEvents: rows.filter { $0.totalTokens == nil }.count,
            models: models.values.sorted { $0.costMicros == $1.costMicros ? $0.model < $1.model : $0.costMicros > $1.costMicros },
            daily: days, projection: projection, eventCount: rows.count)
    }
}
