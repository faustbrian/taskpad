import AppKit

// Draw each icon resolution directly, so small Dock/Finder icons stay crisp.
// Usage: swift scripts/make-icon.swift /path/to/TaskPad.iconset
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    let paper = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 180, yRadius: 180)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -18); shadow.shadowBlurRadius = 26; shadow.set()
    NSColor(srgbRed: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill(); paper.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    paper.addClip()
    let header = NSBezierPath(rect: NSRect(x: 100, y: 704, width: 824, height: 220))
    NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.23, blue: 0.24, alpha: 1),
               ending: NSColor(srgbRed: 0.09, green: 0.10, blue: 0.11, alpha: 1))!.draw(in: header, angle: 90)
    NSColor(srgbRed: 0.16, green: 0.18, blue: 0.19, alpha: 1).setStroke()
    for (index, y) in [570.0, 430, 290].enumerated() {
        let dot = NSBezierPath(ovalIn: NSRect(x: 237, y: y - 28, width: 56, height: 56))
        if index == 0 {
            NSColor(srgbRed: 0.12, green: 0.14, blue: 0.15, alpha: 1).setFill(); dot.fill()
        } else { dot.lineWidth = 8; dot.stroke() }
        let line = NSBezierPath(); line.move(to: NSPoint(x: 350, y: y))
        line.line(to: NSPoint(x: 785 - Double(index) * 54, y: y))
        line.lineWidth = 16; line.lineCapStyle = .round; line.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.35).setStroke(); paper.lineWidth = 3; paper.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try drawIcon(pixels: size * scale).write(to: output.appendingPathComponent(name))
    }
}
