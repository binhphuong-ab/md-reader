// Draws the MD Reader icon into an .iconset folder: swift tools/make-icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func draw(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = s / 1024
    let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)
    NSGradient(colors: [color(0x2A3150), color(0x15171C)])!.draw(in: squircle, angle: -90)
    color(0xFFFFFF, 0.08).setStroke(); squircle.lineWidth = 4 * k; squircle.stroke()

    // The Markdown mark: an "M" and a down arrow.
    let blue = color(0x7AA7FF), violet = color(0xB89BFF)
    let m = NSBezierPath()
    m.move(to: NSPoint(x: 250 * k, y: 330 * k))
    m.line(to: NSPoint(x: 250 * k, y: 690 * k))
    m.line(to: NSPoint(x: 390 * k, y: 530 * k))
    m.line(to: NSPoint(x: 530 * k, y: 690 * k))
    m.line(to: NSPoint(x: 530 * k, y: 330 * k))
    m.lineWidth = 78 * k; m.lineCapStyle = .round; m.lineJoinStyle = .round
    blue.setStroke(); m.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 700 * k, y: 690 * k))
    stem.line(to: NSPoint(x: 700 * k, y: 470 * k))
    stem.lineWidth = 78 * k; stem.lineCapStyle = .round
    violet.setStroke(); stem.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 580 * k, y: 470 * k))
    head.line(to: NSPoint(x: 820 * k, y: 470 * k))
    head.line(to: NSPoint(x: 700 * k, y: 320 * k))
    head.close()
    head.lineJoinStyle = .round; head.lineWidth = 24 * k
    violet.setFill(); head.fill(); violet.setStroke(); head.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = draw(CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
    }
}
