import AppKit

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
MainActor.assumeIsolated {
    _ = NSApplication.shared
    for language in [AppLanguage.portuguese, .english] {
        AppLanguage.current = language
        let about = AboutWindow(version: "9.1.0", build: "42", icon: NSImage(size: NSSize(width: 72, height: 72)))
        let content = about.window!.contentView!
        func all(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(all) }
        check(!all(content).contains { $0 is NSScrollView }, "The About window has no scrolling area")
        check(content.subviews.allSatisfy { content.bounds.contains($0.frame) }, "Everything fits inside the window")
        for field in all(content).compactMap({ $0 as? NSTextField }) {
            let needed = field.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: field.frame.width, height: 1000)).height
            check(field.frame.height >= needed, "No text is cut: \(field.stringValue)")
        }
        let texts = all(content).compactMap { $0 as? NSTextField }.map(\.stringValue)
        check(texts.contains(L("Versão 9.1.0 (42)", "Version 9.1.0 (42)")), "The version and build are shown")
        check(about.links.map(\.url) == [ProjectLinks.authorProfile, ProjectLinks.repository, ProjectLinks.releases, ProjectLinks.issues, ProjectLinks.license], "The author comes first, then the project links")
        check(about.links[0].button.attributedTitle.string == "Renan Eiras Melo" && ProjectLinks.authorProfile.host == "www.linkedin.com", "The author is named in full and links to LinkedIn")
        let frames = about.links.map(\.button.frame)
        check(zip(frames, frames.dropFirst()).allSatisfy { $1.minY - $0.maxY >= 2 && $1.minY - $0.maxY <= 12 }, "Links sit on their own lines, close but not touching")
        var opened: [URL] = []; about.open = { opened.append($0) }
        for link in about.links { link.button.performClick(nil) }
        check(opened == about.links.map(\.url), "Clicking each link opens its own address")
    }
    print("PASS: About window without scrolling, spaced links that open their addresses")
}
