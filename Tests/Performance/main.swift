import AppKit
import CoreImage
import Metal
import QuartzCore

// Synthetic pixels only: no desktop capture or Screen Recording permission.
// Run separately from other graphics tests. This measures isolated render work,
// not drawable acquisition, display presentation, or physical-lid latency.
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
      let screen = NSScreen.screens.first(where: {
          ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
              .map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
      }) else { fatalError("A Metal GPU and open built-in display are required") }

let width = Int(screen.frame.width * screen.backingScaleFactor)
let height = Int(screen.frame.height * screen.backingScaleFactor)
let bounds = CGRect(x: 0, y: 0, width: width, height: height)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                       bytesPerRow: width * 4, space: colorSpace,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bitmap.setFillColor(CGColor(gray: 1, alpha: 1))
bitmap.fill(bounds)
bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
for y in stride(from: 0, to: height, by: 24) {
    for x in stride(from: (y / 24) % 2 == 0 ? 0 : 24, to: width, by: 48) {
        bitmap.fill(CGRect(x: x, y: y, width: 24, height: 24))
    }
}
let capturedImage = CIImage(cgImage: bitmap.makeImage()!)
let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                         width: width, height: height, mipmapped: false)
descriptor.usage = [.shaderWrite, .renderTarget, .shaderRead]
descriptor.storageMode = .private
let texture = device.makeTexture(descriptor: descriptor)!
let useTextureSource = CommandLine.arguments.contains("--texture-source")
// Optional comparison isolates repeated screenshot-image preparation from
// filter encoding. Keep the texture alive throughout the benchmark.
var sourceTexture: MTLTexture?
let input: CIImage
var sourcePreparationMilliseconds = 0.0
if useTextureSource {
    let started = CACurrentMediaTime()
    sourceTexture = device.makeTexture(descriptor: descriptor)!
    let uploadContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
    let uploadCommand = queue.makeCommandBuffer()!
    uploadContext.render(capturedImage, to: sourceTexture!, commandBuffer: uploadCommand,
                         bounds: bounds, colorSpace: colorSpace)
    uploadCommand.commit()
    uploadCommand.waitUntilCompleted()
    precondition(uploadCommand.status == .completed, "Synthetic source upload failed")
    input = CIImage(mtlTexture: sourceTexture!, options: [.colorSpace: colorSpace])!
    sourcePreparationMilliseconds = (CACurrentMediaTime() - started) * 1000
} else {
    input = capturedImage
}

func summary(_ values: [Double]) -> [String: Double] {
    let sorted = values.sorted()
    func percentile(_ fraction: Double) -> Double {
        sorted[min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * fraction)) - 1))]
    }
    return ["p50": percentile(0.50), "p95": percentile(0.95), "p99": percentile(0.99), "max": sorted.last!]
}

var scenarios: [[String: Any]] = []
for radius in [36.0, 80.0] {
    for progress in [0.1, 0.5, 0.9] {
        // A new context exposes first-use compilation/texture upload cost.
        let context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        var settings = BlurSettings()
        settings.radius = radius
        var cpu: [Double] = [], gpu: [Double] = [], completed: [Double] = []
        var cold: [String: Double] = [:]
        for index in 0..<101 {
            autoreleasepool {
                let command = queue.makeCommandBuffer()!
                let started = CACurrentMediaTime()
                // Include a small change on every frame, as in an active fold.
                let p = progress + Double(index % 10) * 0.0001
                let output = BlurFilter.fold(image: input, progress: p, settings: settings,
                                             pixelsPerPoint: screen.backingScaleFactor)
                context.render(output, to: texture, commandBuffer: command, bounds: bounds, colorSpace: colorSpace)
                command.commit()
                let submitted = CACurrentMediaTime()
                command.waitUntilCompleted()
                precondition(command.status == .completed, command.error?.localizedDescription ?? "GPU command failed")
                let cpuMilliseconds = (submitted - started) * 1000
                let gpuMilliseconds = (command.gpuEndTime - command.gpuStartTime) * 1000
                let completedMilliseconds = (CACurrentMediaTime() - started) * 1000
                if index == 0 {
                    cold = ["cpuSubmitMilliseconds": cpuMilliseconds, "gpuMilliseconds": gpuMilliseconds,
                            "completionMilliseconds": completedMilliseconds]
                } else {
                    cpu.append(cpuMilliseconds)
                    gpu.append(gpuMilliseconds)
                    completed.append(completedMilliseconds)
                }
            }
        }
        scenarios.append(["radiusPoints": radius, "progress": progress, "warmSamples": cpu.count,
                          "cold": cold, "warmCpuSubmitMilliseconds": summary(cpu),
                          "warmGpuMilliseconds": summary(gpu), "warmCompletionMilliseconds": summary(completed)])
    }
}
let result: [String: Any] = [
    "scope": "Synthetic isolated Metal rendering; excludes drawable wait and display presentation",
    "source": useTextureSource ? "preuploaded Metal texture" : "screenshot-like CGImage",
    "sourcePreparationMilliseconds": sourcePreparationMilliseconds,
    "gpu": device.name, "os": ProcessInfo.processInfo.operatingSystemVersionString,
    "width": width, "height": height, "pixelsPerPoint": screen.backingScaleFactor,
    "maximumRefreshRate": screen.maximumFramesPerSecond, "scenarios": scenarios
]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
