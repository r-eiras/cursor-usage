import AppKit

@MainActor enum CursorMark {
    private static let images: NSCache<NSNumber, NSImage> = { let cache = NSCache<NSNumber, NSImage>(); cache.countLimit = 8; return cache }()
    private static let sourceLogo: NSImage? = Bundle.main.url(forResource: "Cursor", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    // A dot in the accent color after the reading while an update is available.
    static let updateBadge = "●"
    static func configure(_ button: NSButton, title: String, showsIcon: Bool, style: MenuIconStyle = .cursor, updateBadge: Bool = false) {
        let icon = showsIcon ? (style == .app ? appImage() : image()) : nil
        if button.image !== icon { button.image = icon }
        if button.font == nil || button.font?.pointSize != 11 { button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium) }
        if button.imagePosition != .imageLeading { button.imagePosition = .imageLeading }
        let displayed = icon == nil && title.isEmpty ? "C" : title
        let badge = updateBadge ? (displayed.isEmpty ? Self.updateBadge : " " + Self.updateBadge) : ""
        if button.title != displayed + badge || button.attributedTitle.length == 0 {
            button.title = displayed + badge
            let text = NSMutableAttributedString(string: displayed, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.labelColor])
            text.append(NSAttributedString(string: badge, attributes: [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.controlAccentColor, .baselineOffset: 2]))
            button.attributedTitle = text
        }
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
