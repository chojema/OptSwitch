import AppKit

/// Explains the one permission needed to switch per window. macOS does not list this app by itself,
/// so the user adds it with the + button in System Settings.
final class PermissionGuide: NSWindowController {
    init() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Chojema OptSwitch"
        window.level = .floating  // stay visible beside System Settings
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let title = NSTextField(labelWithString: text("문서(창)별로 전환하려면 권한을 한 번 허용해야 합니다.",
                                                     "Switching per window needs one permission."))
        title.font = .boldSystemFont(ofSize: 14)

        // macOS 27 renamed the Accessibility list (title shown in English even in Korean) and dropped its switches.
        let modern = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        let list = modern ? "System & App Protection Override" : text("손쉬운 사용", "Accessibility")
        // "Choose specific apps" would limit the switcher to those apps, so ask for the full override.
        let last = modern ? text("3. ‘Choose Apps … to Control’ 창이 나오면 맨 아래의 ‘Override System Protections’를 누르고, 암호나 Touch ID로 확인합니다.",
                                 "3. When “Choose Apps … to Control” appears, click “Override System Protections” at the bottom, then confirm with your password or Touch ID.")
                          : text("3. 목록에 생긴 Chojema OptSwitch의 스위치를 켭니다.", "3. Turn on the switch next to Chojema OptSwitch.")
        let steps = NSTextField(wrappingLabelWithString: text(
            "열린 설정 창의 ‘\(list)’ 화면에서\n\n1. 목록 맨 아래의 + 버튼을 누릅니다.\n2. 응용 프로그램 폴더에서 Chojema OptSwitch를 고르고 ‘열기’를 누릅니다.\n\(last)\n\n허용되면 이 창이 저절로 닫히고 바로 문서별로 전환됩니다. 허용하기 전에는 앱별로 전환됩니다.",
            "In the “\(list)” screen of System Settings:\n\n1. Click the + button below the list.\n2. Choose Chojema OptSwitch in the Applications folder and click Open.\n\(last)\n\nThis window closes by itself and switching works per window. Until then, the switcher works per app."))

        let note = NSTextField(wrappingLabelWithString: text(
            "이미 목록에 있는데 문서별로 전환되지 않으면(업데이트 뒤에 생길 수 있습니다) 항목을 선택해 − 버튼으로 지운 뒤 다시 추가합니다.",
            "If it is already listed but switching is not per window (this can happen after an update), select it, remove it with the − button, then add it again."))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let open = NSButton(title: text("설정 다시 열기", "Open Settings Again"), target: nil, action: #selector(openSettings))
        open.target = self
        open.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, steps, note, open])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        for label in [steps, note] { label.preferredMaxLayoutWidth = 340 }
        stack.widthAnchor.constraint(equalToConstant: 388).isActive = true
        window.contentView = stack
        window.layoutIfNeeded()
        window.setContentSize(stack.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {  // left side, so the Settings list stays visible
            window.setFrameOrigin(NSPoint(x: screen.minX + 40, y: screen.midY - window.frame.height / 2))
        }
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        openSettings()
        showWindow(nil)
        NSApp.activate()
        window?.orderFrontRegardless()
    }

    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
