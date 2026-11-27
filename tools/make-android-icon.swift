// Draws the Android adaptive-icon foreground (black "MD" + deep-green bar on transparent),
// 108dp canvas with the artwork inside the 66dp safe zone.
//   swift tools/make-android-icon.swift <res dir>   → <res>/mipmap-{mdpi…xxxhdpi}/ic_launcher_fg.png
import AppKit

let res = CommandLine.arguments.dropFirst().first ?? "res"
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let ink = color(0x14181A), green = color(0x1F6B47)

func draw(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = s / 108                                  // 1 dp in pixels
    let base = NSFont.systemFont(ofSize: 37 * k, weight: .heavy)
    let f = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 37 * k) } ?? base
    let text = NSMutableAttributedString(string: "M", attributes: [.font: f, .foregroundColor: ink, .kern: -1.1 * k])
    text.append(NSAttributedString(string: "D", attributes: [.font: f, .foregroundColor: ink]))
    let size = text.size()
    // Letters + gap + bar form one block centred on the canvas (AppKit's y axis points up).
    let barH = 3.2 * k, gap = 6 * k
    let blockH = f.capHeight + gap + barH
    let barY = 54 * k - blockH / 2
    let baseline = barY + barH + gap
    text.draw(at: NSPoint(x: 54 * k - size.width / 2, y: baseline + f.descender))
    let bar = NSBezierPath(roundedRect: NSRect(x: 54 * k - 17 * k, y: barY, width: 34 * k, height: barH),
                           xRadius: barH / 2, yRadius: barH / 2)
    green.setFill(); bar.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (dir, px) in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)] {
    let folder = "\(res)/mipmap-\(dir)"
    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    try! draw(CGFloat(px)).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(folder)/ic_launcher_fg.png"))
}
