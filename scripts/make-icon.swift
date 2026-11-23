// Draws the app icon and writes Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func rounded(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius) }

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024  // design on a 1024 grid, macOS icon body is 824 with a 100 margin

    // Body with a soft drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824).applying(.init(scaleX: s, y: s))
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.shadowBlurRadius = 24 * s
    shadow.set()
    NSColor.black.setFill()
    rounded(body, 185 * s).fill()
    NSGraphicsContext.restoreGraphicsState()
    rounded(body, 185 * s).addClip()
    NSGradient(starting: NSColor(srgbRed: 0.27, green: 0.55, blue: 0.98, alpha: 1),
               ending: NSColor(srgbRed: 0.33, green: 0.24, blue: 0.85, alpha: 1))!.draw(in: body, angle: -60)

    // Back window, then front window offset down-right: switching between windows.
    func window(_ x: CGFloat, _ y: CGFloat, alpha: CGFloat) -> CGRect {
        let r = CGRect(x: x, y: y, width: 470, height: 380).applying(.init(scaleX: s, y: s))
        NSColor.white.withAlphaComponent(alpha).setFill()
        rounded(r, 56 * s).fill()
        return r
    }
    _ = window(215, 407, alpha: 0.35)
    let front = window(340, 237, alpha: 0.96)
    // Title bar dots on the front window.
    for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        color.setFill()
        NSBezierPath(ovalIn: CGRect(x: front.minX + (48 + CGFloat(i) * 44) * s, y: front.maxY - 66 * s, width: 26 * s, height: 26 * s)).fill()
    }
    // Option key symbol.
    let glyph = NSAttributedString(string: "⌥", attributes: [
        .font: NSFont.systemFont(ofSize: 250 * s, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.31, green: 0.30, blue: 0.88, alpha: 1),
    ])
    let g = glyph.size()
    glyph.draw(at: NSPoint(x: front.midX - g.width / 2, y: front.midY - g.height / 2 - 22 * s))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try task.run()
task.waitUntilExit()
try draw(size: 1024).representation(using: .png, properties: [:])!.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-preview.png"))
print(task.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed")
