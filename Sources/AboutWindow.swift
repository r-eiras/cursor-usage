import AppKit

// The About window: a fixed layout instead of the standard panel, whose credits sit in a short scroll view.
// Every link is a real button, one per line, so it is easy to read and to click.
@MainActor final class AboutWindow: NSWindowController {
    static let size = NSSize(width: 320, height: 360)
    // Opens a link; replaceable so tests can see which link a click opens.
    var open: (URL) -> Void = { NSWorkspace.shared.open($0) }
    private(set) var links: [(button: NSButton, url: URL)] = []

    init(version: String, build: String, icon: NSImage) {
        let window = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = L("Sobre o Cursor Usage", "About Cursor Usage"); window.isReleasedWhenClosed = false; window.hidesOnDeactivate = false
        super.init(window: window)
        let content = FlippedView(frame: NSRect(origin: .zero, size: Self.size)); window.contentView = content
        let image = NSImageView(frame: NSRect(x: (Self.size.width - 64) / 2, y: 18, width: 64, height: 64)); image.image = icon; content.addSubview(image)
        var y: CGFloat = 88
        func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor, height: CGFloat) {
            let field = NSTextField(wrappingLabelWithString: text); field.alignment = .center; field.font = .systemFont(ofSize: size, weight: weight); field.textColor = color
            // Each text takes the height it needs at this width, so no line is cut.
            let width = Self.size.width - 40, needed = ceil(field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 1000)).height ?? height)
            field.frame = NSRect(x: 20, y: y, width: width, height: max(height, needed)); content.addSubview(field); y += max(height, needed)
        }
        label(ProjectLinks.name, size: 17, weight: .semibold, height: 24)
        label(L("Versão \(version) (\(build))", "Version \(version) (\(build))"), size: 11, color: .secondaryLabelColor, height: 18)
        y += 6
        label(L("Consumo do Cursor na barra de menus.\nProjeto independente, sem vínculo com a Anysphere.", "Cursor usage in the menu bar.\nIndependent project, not affiliated with Anysphere."),
              size: 11, color: .secondaryLabelColor, height: 32)
        y += 8
        label(L("Criado por", "Created by"), size: 11, color: .secondaryLabelColor, height: 16)
        addLink(ProjectLinks.author, ProjectLinks.authorProfile, y: y, in: content, weight: .semibold); y += 20 + 8
        for (title, url) in [(L("Código no GitHub", "Source on GitHub"), ProjectLinks.repository), (L("Novidades das versões", "Release notes"), ProjectLinks.releases),
                             (L("Reportar problema", "Report an issue"), ProjectLinks.issues), (L("Licença MIT", "MIT license"), ProjectLinks.license)] {
            addLink(title, url, y: y, in: content); y += 20
        }
        let height = y + 16
        window.setContentSize(NSSize(width: Self.size.width, height: height)); content.frame.size.height = height
    }
    required init?(coder: NSCoder) { fatalError() }

    private func addLink(_ title: String, _ url: URL, y: CGFloat, in content: NSView, weight: NSFont.Weight = .regular) {
        let button = LinkButton(frame: .zero)
        button.attributedTitle = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 12, weight: weight), .foregroundColor: NSColor.linkColor,
                                                                                .underlineStyle: NSUnderlineStyle.single.rawValue])
        button.isBordered = false; button.target = self; button.action = #selector(follow(_:)); button.toolTip = url.absoluteString
        button.setAccessibilityRole(.link); button.setAccessibilityLabel(title)
        button.sizeToFit(); button.frame = NSRect(x: (Self.size.width - button.frame.width) / 2, y: y, width: button.frame.width, height: 18)
        content.addSubview(button); links.append((button, url))
    }
    @objc private func follow(_ sender: NSButton) { if let url = links.first(where: { $0.button === sender })?.url { open(url) } }
}

private final class FlippedView: NSView { override var isFlipped: Bool { true } }

// A borderless button that shows the pointing hand, like a link.
private final class LinkButton: NSButton {
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
