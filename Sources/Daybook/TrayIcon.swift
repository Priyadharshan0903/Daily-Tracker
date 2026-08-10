import AppKit

/// Menu bar glyphs drawn in code from the "Tray Icons" design (16×16 template images —
/// they auto-invert on dark menu bars and while the item is highlighted).
enum TrayIcon {
    /// Variant 1e "Sunrise" — the workday rising.
    static let sunrise: NSImage = {
        let side: CGFloat = 16
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let path = NSBezierPath()
            path.lineWidth = 1.3
            path.lineCapStyle = .round

            // Design coordinates are SVG (y-down); AppKit is y-up, so y ↦ 16 − y.
            func stroke(from x1: CGFloat, _ y1: CGFloat, to x2: CGFloat, _ y2: CGFloat) {
                path.move(to: NSPoint(x: x1, y: side - y1))
                path.line(to: NSPoint(x: x2, y: side - y2))
            }

            stroke(from: 2.2, 11.2, to: 13.8, 11.2)   // horizon
            path.move(to: NSPoint(x: 5, y: side - 11.2))
            path.appendArc(withCenter: NSPoint(x: 8, y: side - 11.2), radius: 3,
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
    }()
}
