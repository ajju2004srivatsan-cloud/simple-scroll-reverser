import AppKit
import Combine
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    /// First-launch / reopen: float until the window closes or setup finishes in place.
    private var elevatedForDiscoverability = false

    func show(forceAttention: Bool = false) {
        let created = window == nil
        let window = makeWindowIfNeeded()
        AppModel.shared.preparePreferencesPresentation()
        if forceAttention {
            elevatedForDiscoverability = true
        }
        applyPresentation(to: window)

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

    private func applyPresentation(to window: NSWindow) {
        let setup = AppModel.shared.isShowingSetup
        window.title = setup
            ? "\(AppIdentity.displayName) — Setup"
            : AppIdentity.displayName
        // Stay Dock-less (LSUIElement) but float above other apps while setup
        // is showing or the window was opened for discoverability.
        window.level = (setup || elevatedForDiscoverability) ? .floating : .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
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
        observeSetupState()
        return window
    }

    private func observeSetupState() {
        guard cancellables.isEmpty else { return }
        AppModel.shared.$isShowingSetup
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] showingSetup in
                guard let self, let window = self.window else { return }
                if !showingSetup {
                    self.elevatedForDiscoverability = false
                }
                self.applyPresentation(to: window)
            }
            .store(in: &cancellables)
    }

    func windowWillClose(_ notification: Notification) {
        elevatedForDiscoverability = false
        window?.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }
}
