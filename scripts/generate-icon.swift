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

func generateIcon(size: Int, scale: Int) -> NSImage? {
    let pixelSize = size * scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()

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
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.45, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        let symbolSize = symbol.size
        let x = (CGFloat(pixelSize) - symbolSize.width) / 2
        let y = (CGFloat(pixelSize) - symbolSize.height) / 2

        NSColor.white.setFill()
        symbol.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                    from: .zero, operation: .destinationOver, fraction: 1.0)

        let tinted = NSImage(size: symbolSize)
        tinted.lockFocus()
        NSColor.white.set()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSRect(origin: .zero, size: symbolSize).fill(using: .sourceIn)
        tinted.unlockFocus()

        tinted.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let iconsetPath = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("automute/Resources/Assets.xcassets/AppIcon.appiconset")

for info in sizes {
    if let image = generateIcon(size: info.size, scale: info.scale) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { continue }

        let file = iconsetPath.appendingPathComponent("\(info.name).png")
        try? png.write(to: file)
        print("Generated \(info.name).png")
    }
}
print("Done!")
