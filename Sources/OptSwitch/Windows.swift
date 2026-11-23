import AppKit

/// One entry in the switcher: a window, or an app that has no window on screen.
struct SwitchItem {
    let app: NSRunningApplication
    let window: CGWindowID?
    let title: String
}

/// Normal windows on the current screen, front to back.
func visibleWindows() -> [(pid: pid_t, window: CGWindowID)] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
    return list.compactMap { info in
        guard info[kCGWindowLayer] as? Int == 0,
              (info[kCGWindowAlpha] as? Double ?? 1) > 0,
              let pid = info[kCGWindowOwnerPID] as? pid_t,
              let id = info[kCGWindowNumber] as? CGWindowID,
              let bounds = info[kCGWindowBounds] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds),
              rect.width >= 50, rect.height >= 50  // skip tiny helper windows
        else { return nil }
        return (pid, id)
    }
}

// Raising one window of another app needs Accessibility (kAXRaiseAction). The WindowServer calls below
// make the switch immediate and give that window keyboard focus; the byte layout follows the well-known technique.
private typealias SetFront = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
private typealias PostRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

private let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
private func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as _: T.Type) -> T? {
    dlsym(handle ?? UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: T.self) }  // -2 = RTLD_DEFAULT
}
private let setFront = symbol(skyLight, "_SLPSSetFrontProcessWithOptions", as: SetFront.self)
private let postRecord = symbol(skyLight, "SLPSPostEventRecordTo", as: PostRecord.self)
private let processForPID = symbol(nil, "GetProcessForPID", as: ProcessForPID.self)

@_silgen_name("_AXUIElementGetWindow")
private func axWindowID(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// The app's windows as Accessibility elements, keyed by window number. Empty without permission.
private func axWindows(of pid: pid_t) -> [CGWindowID: AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.25)  // a hung app must not freeze the switcher
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return [:] }
    var result: [CGWindowID: AXUIElement] = [:]
    for window in windows {
        var id: CGWindowID = 0
        if axWindowID(window, &id) == .success { result[id] = window }
    }
    return result
}

/// Window titles read through Accessibility, so Screen Recording permission is not needed.
func windowTitles(of pids: Set<pid_t>) -> [CGWindowID: String] {
    var titles: [CGWindowID: String] = [:]
    for pid in pids {
        for (id, window) in axWindows(of: pid) {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
               let title = value as? String, !title.isEmpty { titles[id] = title }
        }
    }
    return titles
}

/// Brings one window to the front. Returns false when it cannot, so the caller falls back to the app.
func focus(window: CGWindowID, of pid: pid_t) -> Bool {
    guard let element = axWindows(of: pid)[window], let setFront, let postRecord, let processForPID else { return false }
    var psn = ProcessSerialNumber()
    guard processForPID(pid, &psn) == noErr, setFront(&psn, window, 0x200) == .success else { return false }  // 0x200: user generated
    var id = window
    for phase: UInt8 in [1, 2] {  // make the window key: press then release
        var record = [UInt8](repeating: 0, count: 0xF8)
        record[0x04] = 0xF8
        record[0x08] = phase
        record[0x3A] = 0x10
        memset(&record[0x20], 0xFF, 0x10)
        memcpy(&record[0x3C], &id, MemoryLayout<CGWindowID>.size)
        _ = postRecord(&psn, &record)
    }
    AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    return true
}
