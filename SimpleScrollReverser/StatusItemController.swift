import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = menuBarImage(enabled: AppModel.shared.settings.enabled, needsAttention: AppModel.shared.permissions.needsAttention)
            button.imagePosition = .imageOnly
            button.toolTip = AppIdentity.displayName
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        self.statusItem = item
        self.menu = menu

        let model = AppModel.shared
        model.$settings
            .combineLatest(model.$permissions)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.refreshIcon()
            }
            .store(in: &cancellables)
        refreshIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    @objc private func toggleEnabled(_ sender: Any?) {
        let model = AppModel.shared
        model.setEnabled(!model.settings.enabled)
    }

    @objc private func toggleMouse(_ sender: Any?) {
        let model = AppModel.shared
        model.setReverseMouse(!model.settings.reverseMouse)
    }

    @objc private func toggleTrackpad(_ sender: Any?) {
        let model = AppModel.shared
        model.setReverseTrackpad(!model.settings.reverseTrackpad)
    }

    @objc private func toggleVertical(_ sender: Any?) {
        let model = AppModel.shared
        model.setReverseVertical(!model.settings.reverseVertical)
    }

    @objc private func toggleHorizontal(_ sender: Any?) {
        let model = AppModel.shared
        model.setReverseHorizontal(!model.settings.reverseHorizontal)
    }

    @objc private func openPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.show()
    }

    @objc private func openSetupGuide(_ sender: Any?) {
        AppModel.shared.showSetupGuide()
        PreferencesWindowController.shared.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func refreshIcon() {
        let model = AppModel.shared
        statusItem?.button?.image = menuBarImage(enabled: model.settings.enabled, needsAttention: model.permissions.needsAttention)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let model = AppModel.shared
        let settings = model.settings

        menu.addItem(toggleItem("Enable Scroll Reverser", isOn: settings.enabled, action: #selector(toggleEnabled)))
        menu.addItem(.separator())
        menu.addItem(toggleItem("Reverse Mouse", isOn: settings.reverseMouse, action: #selector(toggleMouse)))
        menu.addItem(toggleItem("Reverse Trackpad", isOn: settings.reverseTrackpad, action: #selector(toggleTrackpad)))
        menu.addItem(.separator())
        menu.addItem(toggleItem("Reverse Vertical", isOn: settings.reverseVertical, action: #selector(toggleVertical)))
        menu.addItem(toggleItem("Reverse Horizontal", isOn: settings.reverseHorizontal, action: #selector(toggleHorizontal)))
        menu.addItem(.separator())

        if model.permissions.needsAttention {
            let item = NSMenuItem(title: "Permissions Needed…", action: #selector(openSetupGuide), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        let setup = NSMenuItem(title: "Setup Guide…", action: #selector(openSetupGuide), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Simple Scroll Reverser", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func toggleItem(_ title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    private func menuBarImage(enabled: Bool, needsAttention: Bool) -> NSImage? {
        let name: String
        if needsAttention {
            name = "exclamationmark.circle"
        } else if enabled {
            name = "arrow.up.arrow.down"
        } else {
            name = "pause.circle"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: AppIdentity.displayName)
        image?.isTemplate = true
        return image
    }
}
