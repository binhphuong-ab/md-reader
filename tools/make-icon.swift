// Draws the MD Reader icon into an .iconset folder: swift tools/make-icon.swift <out.iconset> [variant]
// White squircle, black "MD" with a deep-green bar underneath (variant c, the one in use).
// Other variants kept for previews: a = all-green MD, b = black M + green D.
import AppKit

let args = CommandLine.arguments.dropFirst()
let out = args.first ?? "AppIcon.iconset"
let variant = args.dropFirst().first ?? "c"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let ink = color(0x14181A)        // near-black
let green = color(0x1F6B47)      // dark green (same family as the app's accents)

func font(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let rounded = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) }
    return rounded ?? base
}

func draw(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = s / 1024

    // macOS icon grid: 824pt squircle centred in 1024, with a soft drop shadow.
    let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.28)
    shadow.shadowBlurRadius = 28 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    shadow.set()
    NSGradient(colors: [color(0xFFFFFF), color(0xF1F3F2)])!.draw(in: squircle, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    color(0x000000, 0.10).setStroke(); squircle.lineWidth = 3 * k; squircle.stroke()

    // "MD", optically centred (a touch above the geometric centre).
    let f = font(400 * k)
    let mColor: NSColor = variant == "a" ? green : ink
    let dColor: NSColor = variant == "b" ? green : (variant == "a" ? green : ink)
    let text = NSMutableAttributedString()
    text.append(NSAttributedString(string: "M", attributes: [.font: f, .foregroundColor: mColor, .kern: -12 * k]))
    text.append(NSAttributedString(string: "D", attributes: [.font: f, .foregroundColor: dColor]))
    let size = text.size()
    let capHeight = f.capHeight
    let lift: CGFloat = variant == "c" ? 40 * k : 14 * k
    let origin = NSPoint(x: 512 * k - size.width / 2,
                         y: 512 * k - capHeight / 2 - (-f.descender) + lift)
    text.draw(at: origin)

    if variant == "c" {   // a short green bar under the letters
        let bar = NSBezierPath(roundedRect: NSRect(x: 330 * k, y: 300 * k, width: 364 * k, height: 34 * k),
                               xRadius: 17 * k, yRadius: 17 * k)
        green.setFill(); bar.fill()
    }

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
