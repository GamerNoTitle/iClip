import AppKit

// Native rasterization of the supplied clipboard geometry, with T replaced by iClip.
// No browser, network service or external image dependency is needed.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = resources.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int, preview: Bool = false) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    if preview {
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    }
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor.black.setStroke()
    NSColor.black.setFill()
    // Outer outline follows the supplied 128…896 body bounds, 85.33 stroke.
    let body = NSBezierPath()
    body.move(to: NSPoint(x: 341.333, y: 853.333))
    body.line(to: NSPoint(x: 256, y: 853.333))
    body.curve(to: NSPoint(x: 170.667, y: 768), controlPoint1: NSPoint(x: 208.872, y: 853.333), controlPoint2: NSPoint(x: 170.667, y: 815.128))
    body.line(to: NSPoint(x: 170.667, y: 170.667))
    body.curve(to: NSPoint(x: 256, y: 85.333), controlPoint1: NSPoint(x: 170.667, y: 123.539), controlPoint2: NSPoint(x: 208.872, y: 85.333))
    body.line(to: NSPoint(x: 768, y: 85.333))
    body.curve(to: NSPoint(x: 853.333, y: 170.667), controlPoint1: NSPoint(x: 815.128, y: 85.333), controlPoint2: NSPoint(x: 853.333, y: 123.539))
    body.line(to: NSPoint(x: 853.333, y: 768))
    body.curve(to: NSPoint(x: 768, y: 853.333), controlPoint1: NSPoint(x: 853.333, y: 815.128), controlPoint2: NSPoint(x: 815.128, y: 853.333))
    body.line(to: NSPoint(x: 682.667, y: 853.333))
    body.lineWidth = 85.333
    body.lineCapStyle = .round
    body.stroke()
    let clip = NSBezierPath(roundedRect: NSRect(x: 341.333, y: 768, width: 341.334, height: 170.667), xRadius: 42.667, yRadius: 42.667)
    clip.lineWidth = 85.333
    clip.stroke()
    let text = NSAttributedString(string: "iClip", attributes: [
        .font: NSFont.systemFont(ofSize: 210, weight: .bold),
        .foregroundColor: NSColor.black
    ])
    let textSize = text.size()
    text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: 400))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

func renderApp(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    func color(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    let blue = color(0x3498DB)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 210, yRadius: 210).fill()
    // SVG coordinates converted from top-left to AppKit's bottom-left origin.
    color(0x1ABC9C).setFill()
    NSBezierPath(roundedRect: NSRect(x: 170.666667, y: 85.333333, width: 682.666666, height: 768),
                 xRadius: 96, yRadius: 96).fill()
    blue.setFill()
    NSBezierPath(roundedRect: NSRect(x: 341.333333, y: 746.666667, width: 341.333334, height: 192),
                 xRadius: 96, yRadius: 96).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 405.333333, y: 810.666667, width: 213.333334, height: 64),
                 xRadius: 32, yRadius: 32).fill()
    for (x, y, width) in [(309.333333, 576.0, 405.333334),
                           (309.333333, 405.333333, 234.666667),
                           (309.333333, 234.666667, 320.0)] {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 64), xRadius: 32, yRadius: 32).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try renderApp(size: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try renderApp(size: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(size: 36).write(to: resources.appendingPathComponent("MenuBarIcon.png"))
try renderApp(size: 1024).write(to: resources.appendingPathComponent("AppIcon-preview.png"))
