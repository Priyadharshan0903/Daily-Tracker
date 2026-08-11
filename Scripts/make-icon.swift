// Generates Resources/Daybook.icns from the same sunrise geometry as the tray
// glyph, in the app's theme colours. Run with:
//
//     swift Scripts/make-icon.swift
//
// Committed output means the normal build doesn't have to run this.
import AppKit
import Foundation

// Theme tokens (see Sources/Daybook/Theme.swift).
let skyTop = NSColor(srgbRed: 0x24 / 255, green: 0x43 / 255, blue: 0x7C / 255, alpha: 1)   // accent-700
let skyBottom = NSColor(srgbRed: 0x3F / 255, green: 0x70 / 255, blue: 0xB8 / 255, alpha: 1) // accent-500
let sun = NSColor(srgbRed: 0xF5 / 255, green: 0xB0 / 255, blue: 0x3F / 255, alpha: 1)       // accent-2-400

/// Design-space glyph, a 16-unit viewBox with the artwork spanning
/// x 2.2–13.8 and y 3.6–13.8 (y grows downward, as in the source SVG).
let glyphMinX: CGFloat = 2.2, glyphMaxX: CGFloat = 13.8
let glyphMinY: CGFloat = 3.6, glyphMaxY: CGFloat = 13.8

func draw(size: CGFloat) {
    // macOS icons sit on a rounded square inset from the canvas: 824pt of
    // artwork with a 185pt corner radius inside a 1024pt grid.
    let inset = size * (100.0 / 1024.0)
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let squircle = NSBezierPath(roundedRect: plate,
                                xRadius: plate.width * 0.2245,
                                yRadius: plate.width * 0.2245)

    NSGradient(colors: [skyTop, skyBottom])?.draw(in: squircle, angle: -90)

    let glyphWidth = plate.width * 0.58
    let scale = glyphWidth / (glyphMaxX - glyphMinX)
    let glyphHeight = (glyphMaxY - glyphMinY) * scale
    let originX = plate.midX - glyphWidth / 2
    let originY = plate.midY - glyphHeight / 2

    // Design coordinates are y-down; AppKit is y-up.
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: originX + (x - glyphMinX) * scale,
                y: originY + (glyphMaxY - y) * scale)
    }

    // Warm sun behind the strokes.
    let dome = NSBezierPath()
    dome.move(to: point(5, 11.2))
    dome.appendArc(withCenter: point(8, 11.2), radius: 3 * scale,
                   startAngle: 180, endAngle: 0, clockwise: true)
    dome.close()
    sun.setFill()
    dome.fill()

    let strokes = NSBezierPath()
    strokes.lineWidth = 1.15 * scale
    strokes.lineCapStyle = .round
    strokes.lineJoinStyle = .round

    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        strokes.move(to: point(x1, y1))
        strokes.line(to: point(x2, y2))
    }

    line(2.2, 11.2, 13.8, 11.2)     // horizon
    strokes.move(to: point(5, 11.2))
    strokes.appendArc(withCenter: point(8, 11.2), radius: 3 * scale,
                      startAngle: 180, endAngle: 0, clockwise: true)
    line(8, 3.6, 8, 5.5)            // top ray
    line(3.6, 5.8, 4.95, 7.15)      // left ray
    line(12.4, 5.8, 11.05, 7.15)    // right ray
    line(4.5, 13.8, 11.5, 13.8)     // ground

    NSColor.white.setStroke()
    strokes.stroke()
}

func writePNG(pixels: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try png.write(to: url)
}

// icon_<points>x<points>[@2x].png — the set macOS expects in an .iconset.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/Daybook.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for variant in variants {
    try writePNG(pixels: variant.pixels,
                 to: iconset.appendingPathComponent("\(variant.name).png"))
}

let output = root.appendingPathComponent("Resources/Daybook.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()

print(iconutil.terminationStatus == 0
      ? "Wrote \(output.path)"
      : "iconutil failed (\(iconutil.terminationStatus))")
