import Foundation
import CoreImage

let width = 256
let height = 256
let colorSpace = CGColorSpaceCreateDeviceRGB()
var pixels = [UInt8](repeating: 255, count: width * height * 4)
for y in 0..<height {
    for x in 0..<width {
        let value: UInt8 = (x / 8) % 2 == 0 ? 0 : 255
        for channel in 0..<3 { pixels[(y * width + x) * 4 + channel] = value }
    }
}
let provider = CGDataProvider(data: Data(pixels) as CFData)!
let source = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let input = CIImage(cgImage: source)
let context = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
func render(radius: Double, dimming: Double = 0, progressive: Bool = false) -> [UInt8] {
    let output = BlurFilter.output(image: input, radius: radius, dimming: dimming, progressive: progressive)
    precondition(output.extent == input.extent, "Blur must keep the display bounds")
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    context.render(output, toBitmap: &bytes, rowBytes: width * 4, bounds: input.extent, format: .RGBA8, colorSpace: colorSpace)
    return bytes
}
func contrast(_ data: [UInt8], y: Int) -> Int {
    abs(Int(data[(y * width + 132) * 4]) - Int(data[(y * width + 140) * 4]))
}
let clear = render(radius: 0)
let blurred = render(radius: 12)
let gradient = render(radius: 8, progressive: true)
let dim = render(radius: 0, dimming: 0.25)
precondition(contrast(clear, y: 128) > 250, "Zero blur must preserve fine detail")
precondition(contrast(blurred, y: 128) < 25, "Blur must remove high-frequency detail")
// The returned bitmap is top-first; Core Image coordinates are bottom-first.
precondition(contrast(gradient, y: 224) > contrast(gradient, y: 8) + 50, "The hinge must stay sharper than the top edge")
precondition(blurred[3] == 255 && blurred[blurred.count - 1] == 255, "Clamped blur must not create transparent edges")
let dimmedWhite = Int(dim[(128 * width + 140) * 4])
precondition((185...200).contains(dimmedWhite), "Dimming must darken without crushing colors")
print("Passed 5 rendering checks (detail, progressive hinge, edges, bounds, darkening)")

func foldBytes(_ source: CIImage, progress: Double, settings: BlurSettings) -> [UInt8] {
    let result = BlurFilter.fold(image: source, progress: progress, settings: settings)
    precondition(result.extent == source.extent, "Projection must preserve display bounds")
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    context.render(result, toBitmap: &bytes, rowBytes: width * 4, bounds: source.extent, format: .RGBA8, colorSpace: colorSpace)
    return bytes
}
func light(_ bytes: [UInt8], x: Int, y: Int) -> Int { Int(bytes[(y * width + x) * 4]) }
let white = CIImage(color: .white).cropped(to: input.extent)
var duo = BlurSettings()
duo.radius = 8
let folded = foldBytes(white, progress: 0.55, settings: duo)
precondition(light(folded, x: 4, y: 24) < light(folded, x: 128, y: 24) / 3, "Soft dark side margins must appear")
precondition(light(folded, x: 128, y: 232) > light(folded, x: 128, y: 24) + 30, "The moving outer edge must darken more than the hinge")
precondition(abs(light(folded, x: 5, y: 48) - light(folded, x: 250, y: 48)) < 3, "Both side borders must be symmetric")
precondition(foldBytes(input, progress: 0, settings: duo) == clear, "An open lid must have no projection, border or tint")
let closed = foldBytes(white, progress: 1, settings: duo)
precondition(stride(from: 0, to: closed.count, by: 4).allSatisfy { closed[$0] == 0 && closed[$0+3] == 255 }, "Full closure must be opaque black")
precondition(foldBytes(white, progress: 0.55, settings: duo) == folded, "Opening must retrace the same fold image")
duo.borderDepth = 0
let noBorder = foldBytes(white, progress: 0.55, settings: duo)
precondition(light(noBorder, x: 4, y: 24) > light(folded, x: 4, y: 24) + 60, "Border control must change side coverage")
duo.duoStyle = false
precondition(foldBytes(input, progress: 0.5, settings: duo) == render(radius: 4, dimming: 0.1, progressive: true), "Disabling Duo mode restores the earlier blur")
duo.duoStyle = true; duo.borderDepth = 1
for p in stride(from: 0.0, through: 1.0, by: 0.1) {
    let frame = foldBytes(input, progress: p, settings: duo)
    precondition(stride(from: 3, to: frame.count, by: 4).allSatisfy { frame[$0] == 255 }, "No transparent gaps across the fold arc")
}
_ = foldBytes(white.transformed(by: CGAffineTransform(translationX: 31, y: 19)), progress: 0.5, settings: duo)
print("Passed 10 Duo rendering checks (borders, shading, symmetry, endpoints, reversal, controls, opacity, translated bounds)")

// Reproduce the reported partial-reopening top strip on a uniform source.
// The first row should remain almost as light as nearby interior pixels.
for radius in [0.0, 8.0, 36.0] {
    var openingSettings = BlurSettings()
    openingSettings.radius = radius
    openingSettings.borderDepth = 1.085
    for progress in [0.02, 0.08, 0.18, 0.28, 0.36] {
        let frame = foldBytes(white, progress: progress, settings: openingSettings)
        precondition(Double(light(frame, x: 128, y: 0)) > Double(light(frame, x: 128, y: 24)) * 0.88,
                     "Partial reopening must not expose a black horizontal top strip (radius \(radius), progress \(progress))")
    }
}
print("Passed 15 top-edge reopening regression cases")

// A synthetic contact sheet for visual review; never uses a desktop capture.
let previewFolder = URL(fileURLWithPath: "build/fold-review", isDirectory: true)
try FileManager.default.createDirectory(at: previewFolder, withIntermediateDirectories: true)
for (index, p) in [0.0, 0.25, 0.5, 0.75, 0.92, 1].enumerated() {
    let frame = BlurFilter.fold(image: input, progress: p, settings: duo)
    try context.writePNGRepresentation(of: frame, to: previewFolder.appendingPathComponent("fold-\(index).png"), format: .RGBA8, colorSpace: colorSpace)
}
