import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show() {
        let created = window == nil
        let window = makeWindowIfNeeded()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        if created {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.moveToActiveSpace]
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
