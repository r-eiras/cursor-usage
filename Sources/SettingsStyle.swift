import AppKit

// Scrollers that fade out after scrolling. With a mouse attached macOS prefers always-visible scrollers and resets
// the style when that preference changes, so the style is pinned here instead of set once.
final class OverlayScrollView: NSScrollView {
    override var scrollerStyle: NSScroller.Style { get { .overlay } set { super.scrollerStyle = .overlay } }
}

// The settings layout shared by every tab: a section title, controls with a muted description under them, and
// hairlines between groups, all on the same left inset.
@MainActor enum SettingsStyle {
    nonisolated static let inset: CGFloat = 16
    @discardableResult static func header(_ text: String, in parent: NSView, x: CGFloat = inset, y: CGFloat, width: CGFloat = 452, size: CGFloat = 13) -> NSTextField {
        let field = NSTextField(labelWithString: text); field.frame = NSRect(x: x, y: y, width: width, height: 20)
        field.font = .systemFont(ofSize: size, weight: .semibold); field.textColor = .labelColor; parent.addSubview(field); return field
    }
    @discardableResult static func note(_ text: String, in parent: NSView, x: CGFloat = inset, y: CGFloat, width: CGFloat = 452, height: CGFloat = 16) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text); field.frame = NSRect(x: x, y: y, width: width, height: height)
        field.font = .systemFont(ofSize: 11); field.textColor = .secondaryLabelColor; parent.addSubview(field); return field
    }
    static func separator(in parent: NSView, x: CGFloat = inset, y: CGFloat, width: CGFloat = 452) {
        let line = HairlineView(frame: NSRect(x: x, y: y, width: width, height: 1)); parent.addSubview(line)
    }
    // A dollar amount typed with a comma or a point and at most two decimals.
    static func dollars(_ text: String) -> Double? {
        let raw = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard raw.range(of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil, let value = Double(raw), value.isFinite else { return nil }
        return value
    }
}

@MainActor private final class HairlineView: NSView {
    override func draw(_ dirtyRect: NSRect) { NSColor.white.withAlphaComponent(0.08).setFill(); bounds.fill() }
}
