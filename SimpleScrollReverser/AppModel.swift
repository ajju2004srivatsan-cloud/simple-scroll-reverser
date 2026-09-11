import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var settings: AppSettings
    @Published private(set) var permissions: PermissionState
    @Published private(set) var loginItemEnabled: Bool
    @Published private(set) var loginItemHint: String?
    @Published private(set) var hasSeenDiscreteWheel: Bool = false
    @Published private(set) var lastDeviceLabel: String?
    @Published private(set) var isShowingSetup: Bool

    var shouldShowPreferencesOnLaunch: Bool {
        !AppSettings.hasCompletedSetup || !permissions.canInstallEventTap
    }

    private let permissionMonitor = PermissionMonitor()
    private let hidMonitor = HIDDeviceMonitor()
    private let eventTap = ScrollEventTap()
    private var wakeObserver: NSObjectProtocol?

    private init() {
        let loaded = AppSettings.load()
        settings = loaded
        SettingsStore.shared.update(loaded)
        let permissionState = PermissionMonitor.currentState()
        permissions = permissionState
        loginItemEnabled = LoginItemService.isEnabled
        loginItemHint = LoginItemService.statusHint
        isShowingSetup = !AppSettings.hasCompletedSetup || !permissionState.canInstallEventTap
    }

    func start() {
        hidMonitor.start()
        eventTap.onDiscreteWheel = { [weak self] in
            Task { @MainActor in
                self?.hasSeenDiscreteWheel = true
            }
        }
        eventTap.onDeviceKind = { [weak self] kind in
            Task { @MainActor in
                self?.lastDeviceLabel = kind == .trackpad ? "Trackpad" : "Mouse"
            }
        }
        permissionMonitor.start { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                let previous = self.permissions
                self.permissions = state
                self.syncEventTap()
                if self.isShowingSetup && !state.needsAttention && previous.needsAttention {
                    self.completeSetup()
                }
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.eventTap.handleWake()
            }
        }
        syncEventTap()
        AppSettings.hasLaunchedBefore = true
    }

    func stop() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        eventTap.stop()
        hidMonitor.stop()
        permissionMonitor.stop()
    }

    func setEnabled(_ enabled: Bool) {
        mutate { $0.enabled = enabled }
    }

    func setReverseMouse(_ enabled: Bool) {
        mutate { $0.reverseMouse = enabled }
    }

    func setReverseTrackpad(_ enabled: Bool) {
        mutate { $0.reverseTrackpad = enabled }
    }

    func setReverseVertical(_ enabled: Bool) {
        mutate { $0.reverseVertical = enabled }
    }

    func setReverseHorizontal(_ enabled: Bool) {
        mutate { $0.reverseHorizontal = enabled }
    }

    func setWheelStepSize(_ value: Int) {
        mutate {
            $0.wheelStepSize = min(max(value, AppSettings.wheelStepSizeRange.lowerBound), AppSettings.wheelStepSizeRange.upperBound)
        }
    }

    func setStartAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            loginItemEnabled = LoginItemService.isEnabled
            loginItemHint = LoginItemService.statusHint
        } catch {
            loginItemEnabled = LoginItemService.isEnabled
            loginItemHint = error.localizedDescription
        }
    }

    func refreshPermissions() {
        permissions = PermissionMonitor.currentState()
        syncEventTap()
    }

    func requestAccessibility() {
        PrivacySettingsOpener.openAccessibilityAndPrompt()
        refreshPermissions()
    }

    func requestInputMonitoring() {
        PrivacySettingsOpener.openInputMonitoringAndPrompt()
        refreshPermissions()
    }

    func openPrivacyAndSecurity() {
        PrivacySettingsOpener.openPrivacyAndSecurity()
    }

    func showSetupGuide() {
        isShowingSetup = true
    }

    func completeSetup() {
        guard permissions.canInstallEventTap else { return }
        AppSettings.hasCompletedSetup = true
        isShowingSetup = false
    }

    func preparePreferencesPresentation() {
        refreshPermissions()
        if !AppSettings.hasCompletedSetup || !permissions.canInstallEventTap {
            isShowingSetup = true
        }
    }

    func openLoginItemsSettings() {
        PrivacySettingsOpener.openLoginItems()
    }

    private func mutate(_ body: (inout AppSettings) -> Void) {
        body(&settings)
        settings.save()
        SettingsStore.shared.update(settings)
        syncEventTap()
    }

    private func syncEventTap() {
        let shouldRun = settings.enabled && permissions.canInstallEventTap
        if shouldRun {
            eventTap.start(deviceMonitor: hidMonitor)
        } else {
            eventTap.stop()
        }
    }
}
