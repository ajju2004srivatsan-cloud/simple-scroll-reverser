import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show(forceAttention: Bool = false) {
        let created = window == nil
        let window = makeWindowIfNeeded()
        AppModel.shared.preparePreferencesPresentation()

        window.title = AppModel.shared.isShowingSetup
            ? "\(AppIdentity.displayName) — Setup"
            : AppIdentity.displayName
        // Stay Dock-less (LSUIElement) but float above other apps so the window
        // is findable when the menu bar extra is hidden or not yet noticed.
        window.level = forceAttention || AppModel.shared.isShowingSetup ? .floating : .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        if created || !isFrameUsable(window.frame) {
            window.setContentSize(NSSize(width: 640, height: 520))
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.arrangeInFront(nil)
    }

    private func isFrameUsable(_ frame: NSRect) -> Bool {
        guard frame.width >= 400, frame.height >= 280 else { return false }
        return NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let hosting = NSHostingController(rootView: PreferencesView())
        hosting.sizingOptions = [.preferredContentSize, .minSize]

        let window = NSWindow(contentViewController: hosting)
        window.title = AppIdentity.displayName
        window.styleMask = [.titled, .closable]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SSRPreferences")
        window.delegate = self
        window.level = .normal
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 640, height: 520))
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
