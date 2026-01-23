#!/usr/bin/env swift

import AppKit

let sizes: [(size: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16"),
    (16, 2, "icon_16x16@2x"),
    (32, 1, "icon_32x32"),
    (32, 2, "icon_32x32@2x"),
    (128, 1, "icon_128x128"),
    (128, 2, "icon_128x128@2x"),
    (256, 1, "icon_256x256"),
    (256, 2, "icon_256x256@2x"),
    (512, 1, "icon_512x512"),
    (512, 2, "icon_512x512@2x"),
]

func generateIcon(size: Int, scale: Int) -> Data? {
    let pixelSize = size * scale

    // Create bitmap with exact pixel dimensions
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = CGFloat(pixelSize) * 0.22

    // Gradient background
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.15, green: 0.15, blue: 0.35, alpha: 1.0),
        NSColor(red: 0.25, green: 0.12, blue: 0.45, alpha: 1.0)
    ])
    gradient?.draw(in: path, angle: -45)

    // SF Symbol
    let symbolPointSize = CGFloat(pixelSize) * 0.45
    let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        let symbolSize = symbol.size
        let x = (CGFloat(pixelSize) - symbolSize.width) / 2
        let y = (CGFloat(pixelSize) - symbolSize.height) / 2

        // Draw white symbol
        NSColor.white.set()
        symbol.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])
}

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let iconsetPath = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("automute/Resources/Assets.xcassets/AppIcon.appiconset")

for info in sizes {
    if let pngData = generateIcon(size: info.size, scale: info.scale) {
        let file = iconsetPath.appendingPathComponent("\(info.name).png")
        try? pngData.write(to: file)
        print("Generated \(info.name).png (\(info.size * info.scale)x\(info.size * info.scale) pixels)")
    }
}
print("Done!")
