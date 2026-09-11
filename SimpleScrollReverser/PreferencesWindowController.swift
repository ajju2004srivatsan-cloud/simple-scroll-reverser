import AppKit
import Combine
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func show(forceAttention _: Bool = false) {
        let window = makeWindowIfNeeded()
        AppModel.shared.preparePreferencesPresentation()
        applyPresentation(to: window)
        if !isFrameUsable(window.frame) {
            window.setContentSize(NSSize(width: 640, height: 520))
            centerOnActiveScreen(window)
        }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.arrangeInFront(nil)
    }

    private func applyPresentation(to window: NSWindow) {
        window.title = AppModel.shared.isShowingSetup
            ? "\(AppIdentity.displayName) — Setup"
            : AppIdentity.displayName
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .moveToActiveSpace, .fullScreenAuxiliary]
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: true)
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
        window.delegate = self
        window.level = .floating
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 640, height: 520))
        window.setFrameAutosaveName("SSRPreferences")
        self.window = window
        observeSetupState()
        return window
    }

    private func observeSetupState() {
        guard cancellables.isEmpty else { return }
        AppModel.shared.$isShowingSetup
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let window = self.window else { return }
                self.applyPresentation(to: window)
            }
            .store(in: &cancellables)
    }

    func windowWillClose(_ notification: Notification) {
        window?.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }
}
