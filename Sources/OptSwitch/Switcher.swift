import AppKit

private let keyTab: Int64 = 48
private let keyEscape: Int64 = 53
private let keyLeft: Int64 = 123
private let keyRight: Int64 = 124

/// Watches the keyboard for Option+Tab, cycles through apps, and activates the choice when Option is released.
final class Switcher {
    private var history: [pid_t] = []  // most recent first
    private var apps: [NSRunningApplication] = []
    private var index = 0
    private var tap: CFMachPort?
    private let panel = SwitcherPanel()

    var isRunning: Bool { tap != nil }

    init() {
        if let front = NSWorkspace.shared.frontmostApplication { history = [front.processIdentifier] }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.history.removeAll { $0 == app.processIdentifier }
            self.history.insert(app.processIdentifier, at: 0)
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.history.removeAll { $0 == app.processIdentifier }
        }
    }

    /// Installs the keyboard tap. Fails until the user grants Accessibility permission; the caller retries.
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, info in
                Unmanaged<Switcher>.fromOpaque(info!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        return true
    }

    // Returning nil swallows the event so the frontmost app never sees Option+Tab.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .flagsChanged:
            if panel.isVisible && !event.flags.contains(.maskAlternate) { commit() }
            return pass
        case .keyDown, .keyUp:
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let down = type == .keyDown
            if key == keyTab && flags.contains(.maskAlternate) && flags.isDisjoint(with: [.maskCommand, .maskControl]) {
                if down { step(flags.contains(.maskShift) ? -1 : 1) }
                return nil
            }
            guard panel.isVisible else { return pass }
            switch key {
            case keyEscape: if down { panel.orderOut(nil) }
            case keyLeft: if down { step(-1) }
            case keyRight: if down { step(1) }
            default: return pass
            }
            return nil
        default:
            return pass
        }
    }

    private func step(_ delta: Int) {
        if !panel.isVisible {
            let candidates = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != .current }
            let byPid = Dictionary(candidates.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
            apps = mruOrder(running: candidates.map(\.processIdentifier), history: history).compactMap { byPid[$0] }
            guard !apps.isEmpty else { return }
            index = 0
            panel.show(apps)
        }
        index = wrap(index + delta, apps.count)
        panel.select(index)
    }

    private func commit() {
        panel.orderOut(nil)
        let app = apps[index]
        if app.isHidden { app.unhide() }
        app.activate()
    }
}

/// The floating row of app icons shown while Option is held.
final class SwitcherPanel: NSPanel {
    private let row = NSStackView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var tiles: [NSView] = []
    private var names: [String] = []

    init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 18

        row.spacing = 6
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        let column = NSStackView(views: [row, nameLabel])
        column.orientation = .vertical
        column.spacing = 8
        column.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        column.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            column.topAnchor.constraint(equalTo: background.topAnchor),
            column.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            nameLabel.widthAnchor.constraint(equalTo: row.widthAnchor),
        ])
        contentView = background
    }

    func show(_ apps: [NSRunningApplication]) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        // Shrink icons so a long app list still fits on screen.
        let iconSize = max(24, min(64, (screen.visibleFrame.width * 0.9 - 28) / CGFloat(apps.count) - 22))

        tiles.forEach { $0.removeFromSuperview() }
        tiles = apps.map { tile(for: $0, size: iconSize) }
        tiles.forEach(row.addArrangedSubview)
        names = apps.map { $0.localizedName ?? "" }

        setContentSize(contentView!.fittingSize)
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.midY - frame.height / 2))
        orderFrontRegardless()
    }

    func select(_ index: Int) {
        for (i, tile) in tiles.enumerated() {
            tile.layer?.backgroundColor = i == index ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.55).cgColor : nil
        }
        nameLabel.stringValue = names[index]
        NSAccessibility.post(element: self, notification: .announcementRequested,
                             userInfo: [.announcement: names[index], .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func tile(for app: NSRunningApplication, size: CGFloat) -> NSView {
        let image = NSImageView(image: app.icon ?? NSImage())
        image.imageScaling = .scaleProportionallyUpOrDown
        image.translatesAutoresizingMaskIntoConstraints = false
        let tile = NSView()
        tile.wantsLayer = true
        tile.layer?.cornerRadius = 10
        tile.addSubview(image)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: size),
            image.heightAnchor.constraint(equalToConstant: size),
            image.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            tile.widthAnchor.constraint(equalToConstant: size + 16),
            tile.heightAnchor.constraint(equalToConstant: size + 16),
        ])
        return tile
    }
}
