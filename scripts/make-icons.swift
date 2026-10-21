// Draws Mullion's app icon and menu bar icon (original artwork, ROADMAP M3) into the asset catalog.
// Run from the repo root after changing the design: swift scripts/make-icons.swift
//
// App icon: a navy macOS rounded square holding a window split by a mullion, its left pane filled,
// as if a window had just been snapped there. Menu bar icon: the same window as a template PDF.
import AppKit

let assets = URL(fileURLWithPath: "App/Resources/Assets.xcassets")

// MARK: App icon

/// Draws the icon on a 1024-unit canvas scaled to `pixels`. Small sizes get heavier lines so the
/// mullion stays visible.
func drawAppIcon(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
    let weight: CGFloat = pixels <= 32 ? 2.2 : pixels <= 64 ? 1.5 : 1

    // Body: the macOS icon grid's 824-unit rounded square, with a soft drop shadow.
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(srgbRed: 0.10, green: 0.13, blue: 0.25, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(
        starting: NSColor(srgbRed: 0.20, green: 0.27, blue: 0.47, alpha: 1),
        ending: NSColor(srgbRed: 0.09, green: 0.12, blue: 0.24, alpha: 1)
    )?.draw(in: body, angle: -90)

    // The window and its panes.
    let line = 30 * weight
    let window = NSRect(x: 222, y: 262, width: 580, height: 500)
    let radius: CGFloat = 56
    let frame = NSBezierPath(roundedRect: window, xRadius: radius, yRadius: radius)
    NSColor.white.withAlphaComponent(0.08).setFill()
    frame.fill()

    // Left pane: clipped to the window's rounded corners, up to the mullion.
    NSGraphicsContext.saveGraphicsState()
    frame.addClip()
    NSGradient(
        starting: NSColor(srgbRed: 0.40, green: 0.80, blue: 1.00, alpha: 1),
        ending: NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1)
    )?.draw(in: NSRect(x: window.minX, y: window.minY, width: window.width / 2, height: window.height), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.setStroke()
    frame.lineWidth = line
    frame.stroke()
    let mullion = NSBezierPath()
    mullion.move(to: NSPoint(x: window.midX, y: window.minY))
    mullion.line(to: NSPoint(x: window.midX, y: window.maxY))
    mullion.lineWidth = line
    mullion.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let png = drawAppIcon(pixels: pixels) else { fatalError("Couldn't draw \(name)") }
        try png.write(to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}

let iconContents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: iconContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appendingPathComponent("Contents.json"))

// MARK: Menu bar icon

/// 18 × 18 pt, black on clear: a template image, so macOS tints it for the menu bar.
let menuSet = assets.appendingPathComponent("MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: menuSet, withIntermediateDirectories: true)
var box = CGRect(x: 0, y: 0, width: 18, height: 18)
guard let pdf = CGContext(menuSet.appendingPathComponent("MenuBarIcon.pdf") as CFURL, mediaBox: &box, nil) else {
    fatalError("Couldn't create the menu bar PDF")
}

pdf.beginPDFPage(nil)
let window = CGRect(x: 1.75, y: 3.25, width: 14.5, height: 11.5)
let outline = CGPath(roundedRect: window, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
pdf.setFillColor(CGColor(gray: 0, alpha: 1))
pdf.saveGState()
pdf.addPath(outline)
pdf.clip()
pdf.fill(CGRect(x: window.minX, y: window.minY, width: window.width / 2, height: window.height))
pdf.restoreGState()
pdf.setStrokeColor(CGColor(gray: 0, alpha: 1))
pdf.setLineWidth(1.5)
pdf.addPath(outline)
pdf.strokePath()
pdf.move(to: CGPoint(x: window.midX, y: window.minY))
pdf.addLine(to: CGPoint(x: window.midX, y: window.maxY))
pdf.strokePath()
pdf.endPDFPage()
pdf.closePDF()

let menuContents: [String: Any] = [
    "images": [["idiom": "universal", "filename": "MenuBarIcon.pdf"]],
    "info": ["author": "xcode", "version": 1],
    "properties": ["template-rendering-intent": "template", "preserves-vector-representation": true],
]
try JSONSerialization.data(withJSONObject: menuContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: menuSet.appendingPathComponent("Contents.json"))
print("Icons written to \(assets.path)")
