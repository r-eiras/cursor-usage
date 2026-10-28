import AppKit

// Scrollers that fade out after scrolling. With a mouse attached macOS prefers always-visible scrollers and resets
// the style when that preference changes, so the style is pinned here instead of set once.
final class OverlayScrollView: NSScrollView {
    // Lists keep scrollers that fade out; a window whose content is mostly below the fold keeps its bar on screen.
    var keepsScrollerVisible = false {
        didSet { if keepsScrollerVisible { verticalScroller = ThinScroller() }; super.scrollerStyle = scrollerStyle; tile() }
    }
    override var scrollerStyle: NSScroller.Style { get { keepsScrollerVisible ? .legacy : .overlay } set { super.scrollerStyle = keepsScrollerVisible ? .legacy : .overlay } }
    // Fading scrollers hide that there is more to see, so a fade with an arrow sits at the bottom while content
    // continues below, and goes away at the end.
    let moreBelow = MoreBelowIndicator()
    var fadeColor: NSColor = .windowBackgroundColor { didSet { moreBelow.color = fadeColor } }
    var showsMoreBelow: Bool { !moreBelow.isHidden }
    override init(frame: NSRect) { super.init(frame: frame); watch() }
    required init?(coder: NSCoder) { super.init(coder: coder); watch() }
    private func watch() {
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMoreBelow), name: NSView.boundsDidChangeNotification, object: contentView)
        addSubview(moreBelow); moreBelow.isHidden = true
    }
    override var documentView: NSView? {
        didSet {
            documentView?.postsFrameChangedNotifications = true
            if let documentView { NotificationCenter.default.addObserver(self, selector: #selector(refreshMoreBelow), name: NSView.frameDidChangeNotification, object: documentView) }
            refreshMoreBelow()
        }
    }
    override func tile() { super.tile(); moreBelow.frame = NSRect(x: 0, y: isFlipped ? bounds.height - 30 : 0, width: bounds.width, height: 30); refreshMoreBelow() }
    @objc func refreshMoreBelow() {
        guard let document = documentView else { moreBelow.isHidden = true; return }
        let visible = contentView.bounds
        let remaining = document.isFlipped ? document.frame.height - visible.maxY : visible.minY
        moreBelow.isHidden = document.frame.height <= visible.height + 1 || remaining <= 4
    }
}

// The bar that stays on screen: a thin rounded knob with no track, instead of the wide classic scroller.
final class ThinScroller: NSScroller {
    static let width: CGFloat = 10
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat { width }
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
    override func draw(_ dirtyRect: NSRect) { drawKnob() }
    override func drawKnob() {
        let knob = rect(for: .knob).insetBy(dx: 2.5, dy: 2)
        guard knob.height > 0 else { return }
        NSColor.secondaryLabelColor.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: knob, xRadius: knob.width / 2, yRadius: knob.width / 2).fill()
    }
}

final class MoreBelowIndicator: NSView {
    var color: NSColor = .windowBackgroundColor { didSet { needsDisplay = true } }
    // Clicks and scrolling pass through to the content underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [color.withAlphaComponent(0.95), color.withAlphaComponent(0)])?.draw(in: bounds, angle: 90)
        guard let arrow = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 10, weight: .semibold)) else { return }
        let tinted = NSImage(size: arrow.size, flipped: false) { rect in arrow.draw(in: rect); NSColor.secondaryLabelColor.set(); rect.fill(using: .sourceAtop); return true }
        tinted.draw(in: NSRect(x: (bounds.width - arrow.size.width) / 2, y: 5, width: arrow.size.width, height: arrow.size.height))
    }
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
