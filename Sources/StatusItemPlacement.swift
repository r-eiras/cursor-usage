import AppKit

enum StatusItemPlacement {
    static let autosaveName = "CursorUsage.Cursor"

    // AppKit can report a visible window even when the camera cutout covers it.
    static func needsRecovery(frame: NSRect, rightArea: NSRect?) -> Bool {
        guard frame.width > 0, frame.height > 0, let rightArea,
              frame.maxY > rightArea.minY else { return false }
        return frame.minX < rightArea.minX || frame.maxX > rightArea.maxX
    }

    static func resetPosition() {
        // This preference belongs only to this app's named status item.
        UserDefaults.standard.set(0, forKey: "NSStatusItem Preferred Position \(autosaveName)")
    }
}
