import AppKit
import Carbon.HIToolbox

private enum Key: UInt32 { case next = 1, previous, left, right }

/// Cycles through windows on Option+Tab, like Alt+Tab on Windows, and brings the choice to the front when
/// Option is released. Keys come from system hot keys and the modifier state; only raising a specific window needs
/// Accessibility permission, and without it the switcher works per app.
final class Switcher {
    private var history: [pid_t] = []  // most recent first
    private var items: [SwitchItem] = []
    private var index = 0
    private var panelKeys: [EventHotKeyRef] = []
    private var poll: Timer?
    private let panel = SwitcherPanel()

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

    /// Registers Option+Tab and Option+Shift+Tab. Fails when another app already owns them.
    func start() -> Bool {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, info in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            Unmanaged<Switcher>.fromOpaque(info!).takeUnretainedValue().pressed(Key(rawValue: id.id))
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        return register(kVK_Tab, optionKey, .next) != nil && register(kVK_Tab, optionKey | shiftKey, .previous) != nil
    }

    private func register(_ key: Int, _ modifiers: Int, _ id: Key) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(key), UInt32(modifiers), EventHotKeyID(signature: 0x4F50_5357, id: id.rawValue),
                                         GetApplicationEventTarget(), 0, &ref)
        return status == noErr ? ref : nil
    }

    private func pressed(_ key: Key?) {
        switch key {
        case .next, .right: step(1)
        case .previous, .left: step(-1)
        case nil: break
        }
    }

    private func step(_ delta: Int) {
        if !panel.isVisible {
            let candidates = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != .current }
            let byPid = Dictionary(candidates.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
            // Without Accessibility a specific window cannot be raised, so keep one entry (the front window) per app.
            var windows = visibleWindows()
            var titles: [CGWindowID: String] = [:]
            if AXIsProcessTrusted() {
                titles = windowTitles(of: Set(windows.map(\.pid)))
            } else {
                var seen = Set<pid_t>()
                windows = windows.filter { seen.insert($0.pid).inserted }
            }
            items = switchOrder(windows: windows.map { ($0.pid, $0.window) }, running: candidates.map(\.processIdentifier), history: history)
                .compactMap { entry in
                    guard let app = byPid[entry.pid] else { return nil }
                    let name = app.localizedName ?? ""
                    let title = entry.window.flatMap { titles[$0] }.map { "\($0) — \(name)" } ?? name
                    return SwitchItem(app: app, window: entry.window, title: title)
                }
            guard !items.isEmpty else { return }
            index = 0
            panel.show(items)
            // Arrows belong to the switcher only while it is open (Option is still held). No Escape:
            // Option+Escape is the system Speak Selection shortcut and reaches it even when registered here.
            panelKeys = [(kVK_LeftArrow, Key.left), (kVK_RightArrow, .right)]
                .compactMap { register($0.0, optionKey, $0.1) }
            // Hot keys only report presses, so watch the modifier state to notice Option being released.
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                if !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) { self?.commit() }
            }
            RunLoop.main.add(timer, forMode: .common)
            poll = timer
        }
        index = wrap(index + delta, items.count)
        panel.select(index)
    }

    private func close() {
        panel.orderOut(nil)
        poll?.invalidate()
        poll = nil
        panelKeys.forEach { UnregisterEventHotKey($0) }
        panelKeys = []
    }

    private func commit() {
        close()
        let item = items[index]
        if let window = item.window, focus(window: window, of: item.app.processIdentifier) { return }
        if item.app.isHidden { item.app.unhide() }
        item.app.activate()
    }
}

/// The floating row of icons shown while Option is held.
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

    func show(_ items: [SwitchItem]) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        // Shrink icons so a long app list still fits on screen.
        let iconSize = max(24, min(64, (screen.visibleFrame.width * 0.9 - 28) / CGFloat(items.count) - 22))

        tiles.forEach { $0.removeFromSuperview() }
        tiles = items.map { tile(for: $0.app, size: iconSize) }
        tiles.forEach(row.addArrangedSubview)
        names = items.map(\.title)

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
