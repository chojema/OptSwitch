import AppKit
import ServiceManagement

private let languageKey = "language"

/// Korean unless the user picked English from the menu.
func text(_ korean: String, _ english: String) -> String {
    UserDefaults.standard.string(forKey: languageKey) == "en" ? english : korean
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let switcher = Switcher()
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: #selector(showGuide), keyEquivalent: "")
    private var guide: PermissionGuide?
    private let loginItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let languageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let koreanItem = NSMenuItem(title: "한국어", action: #selector(chooseLanguage), keyEquivalent: "")
    private let englishItem = NSMenuItem(title: "English", action: #selector(chooseLanguage), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Chojema OptSwitch")

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        koreanItem.representedObject = "ko"
        englishItem.representedObject = "en"
        let languages = NSMenu()
        languages.addItem(koreanItem)
        languages.addItem(englishItem)
        languageItem.submenu = languages
        [permissionItem, loginItem, koreanItem, englishItem].forEach { $0.target = self }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Chojema OptSwitch \(version)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(loginItem)
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu

        if !switcher.start() {
            let alert = NSAlert()
            alert.messageText = text("Option+Tab을 쓸 수 없습니다.", "Option+Tab is not available.")
            alert.informativeText = text("다른 앱이 이미 Option+Tab을 쓰고 있습니다. 그 앱을 종료한 뒤 Chojema OptSwitch를 다시 여세요.",
                                         "Another app is already using Option+Tab. Quit that app, then open Chojema OptSwitch again.")
            NSApp.activate()
            alert.runModal()
        }
        if AXIsProcessTrusted() { return }
        showGuide()
        // Permission is granted in System Settings while we run; close the guide as soon as it is.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.guide?.close()
            self?.guide = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        permissionItem.title = text("문서별 전환 권한 안내…", "Per-Window Switching Permission…")
        permissionItem.isHidden = AXIsProcessTrusted()
        loginItem.title = text("로그인 시 실행", "Launch at Login")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        languageItem.title = text("언어", "Language")
        let english = UserDefaults.standard.string(forKey: languageKey) == "en"
        koreanItem.state = english ? .off : .on
        englishItem.state = english ? .on : .off
        quitItem.title = text("종료", "Quit")
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String, forKey: languageKey)
    }

    @objc private func showGuide() {
        guide?.close()
        guide = PermissionGuide()  // rebuilt each time so it follows the chosen language
        guide?.present()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.presentError(error)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
