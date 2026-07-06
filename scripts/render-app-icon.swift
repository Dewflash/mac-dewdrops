#!/usr/bin/env swift
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
let outputURL = URL(fileURLWithPath: arguments.first ?? "Dewdrops.iconset")
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let defaultSourceURL = rootURL.appendingPathComponent("assets/app-icon.png")
let sourceURL = URL(fileURLWithPath: arguments.dropFirst().first ?? defaultSourceURL.path)

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(
        domain: "DewdropsIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not load icon source at \(sourceURL.path)"]
    )
}

func drawIcon(pixelSize: Int, to url: URL) throws {
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
    ) else {
        throw NSError(domain: "DewdropsIcon", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "DewdropsIcon", code: 3)
    }

    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

    let sourceSize = sourceImage.size
    let sourceSide = min(sourceSize.width, sourceSize.height)
    let cropRect = NSRect(
        x: (sourceSize.width - sourceSide) / 2,
        y: (sourceSize.height - sourceSide) / 2,
        width: sourceSide,
        height: sourceSide
    )

    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: cropRect,
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DewdropsIcon", code: 4)
    }

    try data.write(to: url)
}

let icons: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in icons {
    try drawIcon(pixelSize: size, to: outputURL.appendingPathComponent(filename))
}
