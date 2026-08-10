import AppKit

/// Menu bar glyphs drawn in code from the "Tray Icons" design (template images —
/// they auto-invert on dark menu bars and while the item is highlighted).
enum TrayIcon {
    /// Variant 1e "Sunrise" — the workday rising.
    static let sunrise: NSImage = makeSunrise(pointSize: 18)

    /// Same glyph, sized for the popover header beside the "Daybook" title.
    static let headerMark: NSImage = makeSunrise(pointSize: 20)

    /// The design's artwork sits in a 16-unit viewBox but only spans x 2.2–13.8 and
    /// y 3.6–13.8, so drawing it as-is wastes a third of the canvas on padding and
    /// reads small next to other menu bar icons. Scale that bounding box to fill.
    private static func makeSunrise(pointSize: CGFloat) -> NSImage {
        let minX: CGFloat = 2.2, maxX: CGFloat = 13.8
        let minYUp: CGFloat = 2.2, maxYUp: CGFloat = 12.4   // 16 − design y, flipped for AppKit
        let glyphW = maxX - minX
        let glyphH = maxYUp - minYUp

        let inset: CGFloat = 0.6
        let available = pointSize - inset * 2
        let scale = min(available / glyphW, available / glyphH)
        let offsetX = (pointSize - glyphW * scale) / 2
        let offsetY = (pointSize - glyphH * scale) / 2

        // Design coordinates are SVG (y-down); AppKit is y-up, so y ↦ 16 − y.
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: (x - minX) * scale + offsetX,
                    y: ((16 - y) - minYUp) * scale + offsetY)
        }

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { _ in
            let path = NSBezierPath()
            path.lineWidth = 1.25 * scale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            func stroke(from x1: CGFloat, _ y1: CGFloat, to x2: CGFloat, _ y2: CGFloat) {
                path.move(to: p(x1, y1))
                path.line(to: p(x2, y2))
            }

            stroke(from: 2.2, 11.2, to: 13.8, 11.2)   // horizon
            path.move(to: p(5, 11.2))
            path.appendArc(withCenter: p(8, 11.2), radius: 3 * scale,
                           startAngle: 180, endAngle: 0, clockwise: true)  // sun dome
            stroke(from: 8, 3.6, to: 8, 5.5)          // top ray
            stroke(from: 3.6, 5.8, to: 4.95, 7.15)    // left ray
            stroke(from: 12.4, 5.8, to: 11.05, 7.15)  // right ray
            stroke(from: 4.5, 13.8, to: 11.5, 13.8)   // ground

            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
