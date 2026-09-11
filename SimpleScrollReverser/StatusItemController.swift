import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    func install() {
        precondition(Thread.isMainThread)
        // A previous build used autosaveName "SSRStatusItem", which can restore
        // a hidden extra. Never autosave; clear any leftover.
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible SSRStatusItem")
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position SSRStatusItem")

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true

        if let button = item.button {
            applyAppearance(to: button)
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
        statusItem?.isVisible = true
        guard let button = statusItem?.button else { return }
        applyAppearance(to: button)
    }

    private func applyAppearance(to button: NSStatusBarButton) {
        button.appearsDisabled = false
        button.toolTip = AppIdentity.displayName
        button.setAccessibilityTitle(AppIdentity.displayName)

        let image = Self.statusImage() ?? Self.drawnTemplateImage()
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        button.image = image
        button.title = "⇅"
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = NSFont.menuBarFont(ofSize: 13)
        button.sizeToFit()
        let fitted = button.fittingSize.width
        statusItem?.length = (fitted.isFinite && fitted > 0)
            ? max(NSStatusItem.squareLength, ceil(fitted))
            : NSStatusItem.variableLength
        statusItem?.isVisible = true
    }

    /// Bundled template, then a drawn glyph, then SF Symbols. Nil only if nothing usable loaded.
    private static func statusImage() -> NSImage? {
        if let bundled = usableImage(NSImage(named: "MenuBarIcon")) {
            bundled.isTemplate = true
            return bundled
        }
        if let drawn = usableImage(drawnTemplateImage()) {
            return drawn
        }
        if let symbol = usableImage(NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: AppIdentity.displayName)) {
            symbol.isTemplate = true
            return symbol
        }
        return nil
    }

    private static func usableImage(_ image: NSImage?) -> NSImage? {
        guard let image, image.size.width >= 8, image.size.height >= 8 else { return nil }
        return image
    }

    private static func drawnTemplateImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: NSPoint(x: rect.minX + 2.5, y: rect.midY + 1.5))
            path.line(to: NSPoint(x: rect.minX + 6.5, y: rect.minY + 3.5))
            path.line(to: NSPoint(x: rect.minX + 10.5, y: rect.midY + 1.5))
            path.move(to: NSPoint(x: rect.maxX - 10.5, y: rect.midY - 1.5))
            path.line(to: NSPoint(x: rect.maxX - 6.5, y: rect.maxY - 3.5))
            path.line(to: NSPoint(x: rect.maxX - 2.5, y: rect.midY - 1.5))
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
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
}
