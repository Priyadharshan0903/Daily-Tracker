import AppKit
import SwiftUI

/// The sunrise mark, drawn in code from the "Tray Icons" design so the menu bar,
/// the popover header and the app icon all share one piece of geometry.
enum TrayIcon {
    /// Menu bar glyph. A template image so macOS inverts it for dark menu bars and
    /// while the item is highlighted — a coloured icon can't adapt to either.
    static let sunrise: NSImage = make(pointSize: 18, stroke: .black, sun: nil, isTemplate: true)

    /// Popover header mark. Full colour, matching the app icon's warm sun.
    static let headerMark: NSImage = make(pointSize: 20,
                                          stroke: NSColor(Theme.accent),
                                          sun: NSColor(Theme.orange400))

    /// Large muted mark for the empty state; tinted by the caller.
    static let largeMark: NSImage = make(pointSize: 46, stroke: .black, sun: nil, isTemplate: true)

    /// The design's artwork sits in a 16-unit viewBox but only spans x 2.2–13.8
    /// and y 3.6–13.8, so drawing it as-is wastes a third of the canvas on padding
    /// and reads small next to other menu bar icons. Scale that box to fill.
    private static func make(pointSize: CGFloat,
                             stroke: NSColor,
                             sun: NSColor?,
                             isTemplate: Bool = false) -> NSImage {
        let minX: CGFloat = 2.2, maxX: CGFloat = 13.8
        let minYUp: CGFloat = 2.2, maxYUp: CGFloat = 12.4   // 16 − design y, flipped for AppKit
        let glyphWidth = maxX - minX
        let glyphHeight = maxYUp - minYUp

        let inset: CGFloat = 0.6
        let available = pointSize - inset * 2
        let scale = min(available / glyphWidth, available / glyphHeight)
        let offsetX = (pointSize - glyphWidth * scale) / 2
        let offsetY = (pointSize - glyphHeight * scale) / 2

        // Design coordinates are SVG (y-down); AppKit is y-up, so y ↦ 16 − y.
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: (x - minX) * scale + offsetX,
                    y: ((16 - y) - minYUp) * scale + offsetY)
        }

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { _ in
            if let sun {
                // Warm fill behind the strokes, as on the app icon.
                let dome = NSBezierPath()
                dome.move(to: point(5, 11.2))
                dome.appendArc(withCenter: point(8, 11.2), radius: 3 * scale,
                               startAngle: 180, endAngle: 0, clockwise: true)
                dome.close()
                sun.setFill()
                dome.fill()
            }

            let path = NSBezierPath()
            path.lineWidth = 1.25 * scale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            func line(from x1: CGFloat, _ y1: CGFloat, to x2: CGFloat, _ y2: CGFloat) {
                path.move(to: point(x1, y1))
                path.line(to: point(x2, y2))
            }

            line(from: 2.2, 11.2, to: 13.8, 11.2)     // horizon
            path.move(to: point(5, 11.2))
            path.appendArc(withCenter: point(8, 11.2), radius: 3 * scale,
                           startAngle: 180, endAngle: 0, clockwise: true)  // sun dome
            line(from: 8, 3.6, to: 8, 5.5)            // top ray
            line(from: 3.6, 5.8, to: 4.95, 7.15)      // left ray
            line(from: 12.4, 5.8, to: 11.05, 7.15)    // right ray
            line(from: 4.5, 13.8, to: 11.5, 13.8)     // ground

            stroke.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = isTemplate
        return image
    }
}
