import Foundation
import ServiceManagement

enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusHint: String? {
        switch SMAppService.mainApp.status {
        case .enabled:
            return nil
        case .requiresApproval:
            return "macOS is waiting for you to allow this app in Login Items & Extensions."
        case .notFound:
            return "Start at login works most reliably after you move the app to /Applications."
        case .notRegistered:
            return nil
        @unknown default:
            return nil
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status == .enabled { return }
            try service.register()
        } else {
            if service.status == .notRegistered { return }
            try service.unregister()
        }
    }
}
