import AppKit

extension Notification.Name {
    /// Posted when a second launch should focus the running instance's preferences.
    static let ssrShowPreferences = Notification.Name("com.ajju2004srivatsan.simplescrollreverser.showPreferences")
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = StatusItemController()
    private var distributedObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        handOffToRunningInstanceIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: .ssrShowPreferences,
            object: Bundle.main.bundleIdentifier,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showPreferences()
            }
        }

        AppModel.shared.start()
        statusItem.install()

        if AppModel.shared.shouldShowPreferencesOnLaunch {
            PreferencesWindowController.shared.show(forceAttention: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.stop()
        if let distributedObserver {
            DistributedNotificationCenter.default().removeObserver(distributedObserver)
        }
    }

    @objc func showPreferences() {
        PreferencesWindowController.shared.show(forceAttention: true)
    }

    private func handOffToRunningInstanceIfNeeded() {
        let bundleID = Bundle.main.bundleIdentifier ?? AppIdentity.bundleID
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let existing = others.first else { return }

        DistributedNotificationCenter.default().postNotificationName(
            .ssrShowPreferences,
            object: bundleID,
            userInfo: nil,
            deliverImmediately: true
        )
        existing.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        exit(0)
    }
}

enum AppIdentity {
    static let bundleID = "com.ajju2004srivatsan.simplescrollreverser"
    static let displayName = "Simple Scroll Reverser"
}
