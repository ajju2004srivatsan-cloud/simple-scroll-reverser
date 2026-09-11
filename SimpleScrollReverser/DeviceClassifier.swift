import Foundation
import CoreGraphics

enum DeviceKind: String, Sendable, Equatable {
    case mouse
    case trackpad
}

/// Classifies a scroll event as mouse or trackpad.
///
/// HID last-active device is preferred when available (needed for Magic Mouse,
/// which is a mouse with a continuous touch surface). Otherwise a public
/// CGEvent-field heuristic is used:
/// - Discrete / line-based deltas → mouse wheel
/// - Continuous + gesture/momentum phase → trackpad
/// - Continuous with no gesture phase → Magic Mouse / other smooth mice
enum DeviceClassifier {
    struct EventSignals: Equatable, Sendable {
        var isContinuous: Bool
        var scrollPhase: Int64
        var momentumPhase: Int64
        var scrollCount: Int64
    }

    static func signals(from event: CGEvent) -> EventSignals {
        EventSignals(
            isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
            scrollPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            scrollCount: event.getIntegerValueField(.scrollWheelEventScrollCount)
        )
    }

    static func kind(from signals: EventSignals, hidHint: DeviceKind?) -> DeviceKind {
        if let hidHint {
            return hidHint
        }
        if !signals.isContinuous {
            return .mouse
        }
        if signals.scrollPhase != 0 || signals.momentumPhase != 0 || signals.scrollCount != 0 {
            return .trackpad
        }
        return .mouse
    }

    /// Names and HID usage pages are the public way to tell a Magic Mouse
    /// (mouse) from a Magic Trackpad / built-in trackpad (digitizer touch pad).
    static func kind(productName: String, builtIn: Bool, conformsToTouchPad: Bool, conformsToMouse: Bool) -> DeviceKind {
        let name = productName.lowercased()
        if name.contains("trackpad") || name.contains("touchpad") {
            return .trackpad
        }
        if name.contains("magic mouse") || name.contains("mighty mouse") {
            return .mouse
        }
        if builtIn && conformsToTouchPad {
            return .trackpad
        }
        if conformsToTouchPad && !name.contains("mouse") {
            return .trackpad
        }
        if conformsToMouse {
            return .mouse
        }
        if conformsToTouchPad {
            return .trackpad
        }
        return .mouse
    }
}
