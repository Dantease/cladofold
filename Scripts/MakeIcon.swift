import AppKit

let destination = CommandLine.arguments[1]
let sourceURL = URL(fileURLWithPath: "Resources/Brand/cf-master.png")
guard let artwork = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing cf. master artwork at \(sourceURL.path)")
}
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 65, y: 65, width: 894, height: 894)
        let outline = NSBezierPath(roundedRect: rect, xRadius: 202, yRadius: 202)
        outline.addClip()
        NSGraphicsContext.current?.imageInterpolation = .high
        artwork.draw(in: rect, from: NSRect(origin: .zero, size: artwork.size), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name))
    }
}

// Package PNG representations directly so builds also work inside a sandbox.
func bigEndian(_ integer: Int) -> Data {
    var value = UInt32(integer).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (type, name) in [("icp4", "16x16"), ("icp5", "32x32"), ("icp6", "32x32@2x"), ("ic07", "128x128"), ("ic08", "256x256"), ("ic09", "512x512"), ("ic10", "512x512@2x"), ("ic11", "16x16@2x"), ("ic12", "32x32@2x"), ("ic13", "128x128@2x"), ("ic14", "256x256@2x")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: destination).appendingPathComponent("icon_\(name).png"))
    chunks.append(Data(type.utf8)); chunks.append(bigEndian(png.count + 8)); chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(bigEndian(chunks.count + 8)); icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: destination).deletingPathExtension().appendingPathExtension("icns"))
