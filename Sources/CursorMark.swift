import AppKit

@MainActor enum CursorMark {
    private static let images: NSCache<NSNumber, NSImage> = { let cache = NSCache<NSNumber, NSImage>(); cache.countLimit = 8; return cache }()
    private static let sourceLogo: NSImage? = Bundle.main.url(forResource: "Cursor", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    // A dot in the accent color after the reading while an update is available.
    static let updateBadge = "●"
    // The icon's color follows how much of the allowance or personal limit is used: the menu bar's own color
    // below 30%, then yellow, orange from 60% and red from 90%.
    static func usageColor(_ fraction: Double?) -> NSColor? {
        guard let fraction, fraction >= 0.3 else { return nil }
        return fraction < 0.6 ? .systemYellow : fraction < 0.9 ? .systemOrange : .systemRed
    }
    // Numbers use the same levels, darkened on a light menu bar where yellow and orange text would be hard to read.
    private static let textColors: [NSColor] = [(NSColor.systemYellow, (0.62, 0.45, 0.0)), (.systemOrange, (0.78, 0.36, 0.0)), (.systemRed, (0.80, 0.12, 0.10))].map { color, light in
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? color : NSColor(srgbRed: light.0, green: light.1, blue: light.2, alpha: 1)
        }
    }
    static func textColor(_ fraction: Double?) -> NSColor {
        guard let fraction, fraction >= 0.3 else { return .labelColor }
        return textColors[fraction < 0.6 ? 0 : fraction < 0.9 ? 1 : 2]
    }
    // `parts`, when given, colors each piece of the reading by its own usage; otherwise the text keeps the bar's color.
    static func configure(_ button: NSButton, title: String, showsIcon: Bool, style: MenuIconStyle = .cursor, updateBadge: Bool = false, usage: Double? = nil,
                          parts: [MenuBarPresentation.Part]? = nil) {
        let icon = showsIcon ? self.icon(style: style, usage: usage) : nil
        if button.image !== icon { button.image = icon }
        if button.font == nil || button.font?.pointSize != 11 { button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium) }
        if button.imagePosition != .imageLeading { button.imagePosition = .imageLeading }
        let displayed = icon == nil && title.isEmpty ? "C" : title
        let badge = updateBadge ? (displayed.isEmpty ? Self.updateBadge : " " + Self.updateBadge) : ""
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let pieces = parts.flatMap { $0.map(\.text).joined() == displayed ? $0 : nil } ?? [MenuBarPresentation.Part(text: displayed, usage: nil)]
        let text = NSMutableAttributedString()
        for piece in pieces { text.append(NSAttributedString(string: piece.text, attributes: [.font: font, .foregroundColor: textColor(piece.usage)])) }
        text.append(NSAttributedString(string: badge, attributes: [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.controlAccentColor, .baselineOffset: 2]))
        if button.title != displayed + badge || !button.attributedTitle.isEqual(to: text) {
            button.title = displayed + badge
            button.attributedTitle = text
        }
    }

    // The menu bar icon for a style at a usage level; settings draw its legend with the same images.
    static func icon(style: MenuIconStyle, usage: Double?) -> NSImage {
        let base = style == .app ? appImage() : image()
        return usageColor(usage).map { tinted(base, $0, key: "\(style.rawValue)-\(usage.map { $0 < 0.6 ? 1 : $0 < 0.9 ? 2 : 3 } ?? 0)") } ?? base
    }
    private static let tintedImages: NSCache<NSString, NSImage> = { let cache = NSCache<NSString, NSImage>(); cache.countLimit = 8; return cache }()
    // One cached image per style and level, so the button keeps the same instance between readings.
    private static func tinted(_ base: NSImage, _ color: NSColor, key: String) -> NSImage {
        if let cached = tintedImages.object(forKey: key as NSString) { return cached }
        let result = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect); color.set(); rect.fill(using: .sourceAtop); return true
        }
        tintedImages.setObject(result, forKey: key as NSString); return result
    }

    private static let appImages: NSCache<NSNumber, NSImage> = { let cache = NSCache<NSNumber, NSImage>(); cache.countLimit = 8; return cache }()
    static func appImage(size: CGFloat = 16, template: Bool = true) -> NSImage {
        let key = NSNumber(value: Double(size) * 2 + (template ? 1 : 0))
        if let cached = appImages.object(forKey: key) { return cached }
        let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = rect.width / 16
            let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
            let color = template ? NSColor.black : NSColor(srgbRed: 0.42, green: 0.87, blue: 0.73, alpha: 1)
            color.setStroke(); color.setFill()
            let arc = NSBezierPath(); arc.lineWidth = 1.7
            arc.appendArc(withCenter: NSPoint(x: 8, y: 7.33), radius: 6.67, startAngle: 0, endAngle: 180)
            arc.stroke()
            let needle = NSBezierPath(); needle.lineWidth = 1.5; needle.lineCapStyle = .round
            needle.move(to: NSPoint(x: 8, y: 7.33)); needle.line(to: NSPoint(x: 11.67, y: 11.33)); needle.stroke()
            NSBezierPath(ovalIn: NSRect(x: 7, y: 6.33, width: 2, height: 2)).fill()
            let base = NSBezierPath(); base.lineWidth = 1.4
            base.move(to: NSPoint(x: 2, y: 3.33)); base.line(to: NSPoint(x: 14, y: 3.33)); base.stroke()
            transform.invert(); transform.concat(); return true
        }
        result.isTemplate = template; appImages.setObject(result, forKey: key); return result
    }
    static func image(size: CGFloat = 16) -> NSImage {
        let key = NSNumber(value: Double(size))
        if let cached = images.object(forKey: key) { return cached }
        if let logo = sourceLogo {
            let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                logo.draw(in: rect); return true
            }
            images.setObject(result, forKey: key); return result
        }
        let fallback = NSImage(systemSymbolName: "chart.pie", accessibilityDescription: "Cursor") ?? NSImage(size: NSSize(width: size, height: size))
        fallback.size = NSSize(width: size, height: size); images.setObject(fallback, forKey: key); return fallback
    }
}
