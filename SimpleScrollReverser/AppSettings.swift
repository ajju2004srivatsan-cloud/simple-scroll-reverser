import Foundation

/// Persistent user preferences. Safe to snapshot and read from the event-tap thread.
struct AppSettings: Equatable, Sendable {
    var enabled: Bool
    var reverseMouse: Bool
    var reverseTrackpad: Bool
    var reverseVertical: Bool
    var reverseHorizontal: Bool
    /// Fixed line count for discrete (clicky) wheels. `0` keeps the system default.
    var wheelStepSize: Int

    static let `default` = AppSettings(
        enabled: true,
        reverseMouse: true,
        reverseTrackpad: false,
        reverseVertical: true,
        reverseHorizontal: true,
        wheelStepSize: 0
    )

    static let wheelStepSizeRange = 0...8
}

/// Cross-thread snapshot so the CGEvent callback never hops to the main actor.
final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    private let lock = NSLock()
    private var snapshot: AppSettings = .default

    var current: AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    func update(_ settings: AppSettings) {
        lock.lock()
        snapshot = settings
        lock.unlock()
    }
}

extension AppSettings {
    private enum Key {
        static let enabled = "enabled"
        static let reverseMouse = "reverseMouse"
        static let reverseTrackpad = "reverseTrackpad"
        static let reverseVertical = "reverseVertical"
        static let reverseHorizontal = "reverseHorizontal"
        static let wheelStepSize = "wheelStepSize"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        var settings = AppSettings.default
        if defaults.object(forKey: Key.enabled) != nil {
            settings.enabled = defaults.bool(forKey: Key.enabled)
        }
        if defaults.object(forKey: Key.reverseMouse) != nil {
            settings.reverseMouse = defaults.bool(forKey: Key.reverseMouse)
        }
        if defaults.object(forKey: Key.reverseTrackpad) != nil {
            settings.reverseTrackpad = defaults.bool(forKey: Key.reverseTrackpad)
        }
        if defaults.object(forKey: Key.reverseVertical) != nil {
            settings.reverseVertical = defaults.bool(forKey: Key.reverseVertical)
        }
        if defaults.object(forKey: Key.reverseHorizontal) != nil {
            settings.reverseHorizontal = defaults.bool(forKey: Key.reverseHorizontal)
        }
        if defaults.object(forKey: Key.wheelStepSize) != nil {
            let stored = defaults.integer(forKey: Key.wheelStepSize)
            settings.wheelStepSize = min(max(stored, wheelStepSizeRange.lowerBound), wheelStepSizeRange.upperBound)
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: Key.enabled)
        defaults.set(reverseMouse, forKey: Key.reverseMouse)
        defaults.set(reverseTrackpad, forKey: Key.reverseTrackpad)
        defaults.set(reverseVertical, forKey: Key.reverseVertical)
        defaults.set(reverseHorizontal, forKey: Key.reverseHorizontal)
        defaults.set(wheelStepSize, forKey: Key.wheelStepSize)
    }

    static var hasLaunchedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hasLaunchedBefore) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hasLaunchedBefore) }
    }
}
