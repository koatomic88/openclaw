import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDirectory = root.appendingPathComponent("Sources/Assets.xcassets/AppIcon.appiconset")
let markPath = root.appendingPathComponent("Sources/Assets.xcassets/OpenClawIcon.imageset/openclaw-icon.png")

let iconSizes = [
    29, 40, 48, 55, 57, 58, 60, 66, 80, 87, 88, 92, 100, 102, 108, 114,
    120, 172, 180, 196, 216, 234, 258, 1024,
]

func drawAtomIcon(size: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    let previousContext = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    guard let context = NSGraphicsContext.current?.cgContext else {
        NSGraphicsContext.current = previousContext
        throw CocoaError(.fileWriteUnknown)
    }
    let colors = [
        CGColor(red: 0.01, green: 0.025, blue: 0.085, alpha: 1),
        CGColor(red: 0.015, green: 0.075, blue: 0.22, alpha: 1),
        CGColor(red: 0.0, green: 0.0, blue: 0.025, alpha: 1),
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.56, 1.0])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: [])

    context.setBlendMode(.screen)
    let glowColors = [
        CGColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 0.38),
        CGColor(red: 1.0, green: 0.72, blue: 0.18, alpha: 0.0),
    ] as CFArray
    let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: size / 2, y: size / 2),
        startRadius: CGFloat(size) * 0.03,
        endCenter: CGPoint(x: size / 2, y: size / 2),
        endRadius: CGFloat(size) * 0.48,
        options: [])
    context.setBlendMode(.normal)

    let center = CGPoint(x: size / 2, y: size / 2)
    let lineWidth = max(1.2, CGFloat(size) * 0.024)
    let orbitColor = CGColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 0.92)
    let softOrbitColor = CGColor(red: 0.38, green: 0.82, blue: 1.0, alpha: 0.26)

    func strokeOrbit(angle: CGFloat, scaleY: CGFloat, color: CGColor, alpha: CGFloat) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        context.scaleBy(x: 1, y: scaleY)
        context.setStrokeColor(color.copy(alpha: alpha) ?? color)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(
            x: -CGFloat(size) * 0.34,
            y: -CGFloat(size) * 0.34,
            width: CGFloat(size) * 0.68,
            height: CGFloat(size) * 0.68))
        context.restoreGState()
    }

    strokeOrbit(angle: 0, scaleY: 0.34, color: orbitColor, alpha: 0.95)
    strokeOrbit(angle: .pi / 3, scaleY: 0.34, color: orbitColor, alpha: 0.78)
    strokeOrbit(angle: -.pi / 3, scaleY: 0.34, color: orbitColor, alpha: 0.78)
    strokeOrbit(angle: .pi / 2, scaleY: 0.34, color: softOrbitColor, alpha: 0.9)

    context.setFillColor(CGColor(red: 1.0, green: 0.82, blue: 0.34, alpha: 1))
    context.fillEllipse(in: CGRect(
        x: center.x - CGFloat(size) * 0.075,
        y: center.y - CGFloat(size) * 0.075,
        width: CGFloat(size) * 0.15,
        height: CGFloat(size) * 0.15))

    if size >= 80 {
        let title = "ATOM" as NSString
        let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.115, weight: .bold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 1.0, green: 0.84, blue: 0.42, alpha: 0.96),
            .paragraphStyle: paragraph,
            .kern: CGFloat(size) * 0.012,
        ]
        title.draw(
            in: CGRect(
                x: CGFloat(size) * 0.08,
                y: CGFloat(size) * 0.13,
                width: CGFloat(size) * 0.84,
                height: CGFloat(size) * 0.16),
            withAttributes: attributes)
    }

    NSGraphicsContext.current = previousContext
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url)
}

for size in iconSizes {
    try writePNG(try drawAtomIcon(size: size), to: appIconDirectory.appendingPathComponent("\(size).png"))
}
try writePNG(try drawAtomIcon(size: 180), to: markPath)
print("Generated ATOM icons in \(appIconDirectory.path)")
