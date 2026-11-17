// GPL-3.0. Draw the app's mouse icon using native vector paths.
import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(size) / 1024)
        transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 202, yRadius: 202)
        NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.58, blue: 1, alpha: 1),
                   ending: NSColor(calibratedRed: 0.07, green: 0.27, blue: 0.83, alpha: 1))!
            .draw(in: tile, angle: -90)
        let body = NSBezierPath(roundedRect: NSRect(x: 322, y: 204, width: 380, height: 620), xRadius: 190, yRadius: 190)
        NSColor.white.setFill()
        body.fill()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 330, y: 610))
        divider.line(to: NSPoint(x: 694, y: 610))
        divider.lineWidth = 15
        NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.92, alpha: 1).setStroke()
        divider.stroke()
        let wheel = NSBezierPath(roundedRect: NSRect(x: 490, y: 656, width: 44, height: 104), xRadius: 22, yRadius: 22)
        NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.92, alpha: 1).setFill()
        wheel.fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
