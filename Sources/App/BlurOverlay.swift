import AppKit
import CoreImage
import MetalKit
import ScreenCaptureKit

enum OverlayError: LocalizedError {
    case noDisplay, noGPU
    var errorDescription: String? {
        switch self {
        case .noDisplay: return "Open the built-in display to use cladofold."
        case .noGPU: return "The blur renderer could not start."
        }
    }
}

/// A single in-memory frame per fold. No files, recording stream, or network.
@MainActor final class BlurOverlay {
    private var panel: NSPanel?
    private var surface: BlurSurface?
    private var generation = 0
    private var filter: SCContentFilter?
    private var configuration: SCStreamConfiguration?
    private(set) var captureMilliseconds = 0.0
    private(set) var capturing = false
    private(set) var ready = false
    var visible: Bool { panel?.isVisible == true }
    var renderedFrames: Int { surface?.renderedFrames ?? 0 }
    var renderError: String? { surface?.renderError }

    /// Prepare display metadata and GPU/window resources while the desktop is
    /// clear. This holds no captured frame and avoids rebuilding on every fold.
    func prepare(content: SCShareableContent) throws {
        guard filter == nil else { return }
        guard let display = content.displays.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }),
              let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID }) else { throw OverlayError.noDisplay }
        // The panel is hidden until after capture and hidden again on clear.
        let filter = SCContentFilter(display: display, excludingWindows: [])
        if #available(macOS 14.2, *) { filter.includeMenuBar = true }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
        configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
        configuration.showsCursor = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        guard let device = MTLCreateSystemDefaultDevice(), let surface = BlurSurface(frame: screen.frame, device: device) else { throw OverlayError.noGPU }
        surface.pointsToPixels = screen.backingScaleFactor
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = surface
        panel.backgroundColor = .clear
        panel.isOpaque = true
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        // The system menu remains above the overlay, so the off switch stays usable.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        self.panel = panel
        self.surface = surface
        self.filter = filter
        self.configuration = configuration
    }

    func capture() async throws {
        guard !capturing, !ready else { return }
        capturing = true
        generation += 1
        let request = generation
        let started = Date()
        defer { if generation == request { capturing = false } }
        if filter == nil {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard request == generation, !Task.isCancelled else { return }
            try prepare(content: content)
        }
        guard let filter, let configuration else { throw OverlayError.noDisplay }
        let snapshot = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard request == generation, !Task.isCancelled, let surface else { return }
        surface.snapshot = CIImage(cgImage: snapshot)
        captureMilliseconds = Date().timeIntervalSince(started) * 1000
        ready = true
    }

    func render(progress: Double, settings: BlurSettings) {
        guard ready, let panel, let surface else { return }
        surface.progress = progress
        surface.settings = settings
        // Keep only a tiny onset blend; the former 4% ramp hid early lid motion.
        panel.alphaValue = min(1, progress / 0.005)
        if !panel.isVisible { panel.orderFrontRegardless() }
        surface.draw()
    }

    func clear(discardResources: Bool = false) {
        generation += 1
        capturing = false
        ready = false
        panel?.orderOut(nil)
        surface?.snapshot = nil
        surface?.releaseDrawables()
        surface?.resetFrameStats()
        if discardResources {
            panel?.close()
            panel = nil
            surface = nil
            filter = nil
            configuration = nil
        }
    }
}

@MainActor private final class BlurSurface: MTKView, MTKViewDelegate {
    var snapshot: CIImage?
    var progress = 0.0
    var settings = BlurSettings()
    private(set) var renderedFrames = 0
    private(set) var renderError: String?
    var pointsToPixels = 2.0
    private var frameGeneration = 0
    private let context: CIContext
    private let commands: MTLCommandQueue
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init?(frame: NSRect, device: MTLDevice) {
        guard let commands = device.makeCommandQueue() else { return nil }
        self.commands = commands
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        super.init(frame: frame, device: device)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        autoResizeDrawable = true
        isPaused = true
        enableSetNeedsDisplay = false
        delegate = self
    }

    required init(coder: NSCoder) { fatalError("Use init(frame:device:)") }

    func resetFrameStats() {
        frameGeneration += 1
        renderedFrames = 0
        renderError = nil
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let snapshot, let drawable = currentDrawable, let command = commands.makeCommandBuffer() else { return }
        var output = BlurFilter.fold(image: snapshot, progress: progress, settings: settings, pixelsPerPoint: pointsToPixels)
        output = output.transformed(by: CGAffineTransform(scaleX: drawableSize.width / snapshot.extent.width, y: drawableSize.height / snapshot.extent.height))
        context.render(output, to: drawable.texture, commandBuffer: command, bounds: CGRect(origin: .zero, size: drawableSize), colorSpace: colorSpace)
        command.present(drawable)
        let generation = frameGeneration
        command.addCompletedHandler { [weak self] result in
            let error = result.error?.localizedDescription
            DispatchQueue.main.async {
                guard self?.frameGeneration == generation else { return }
                if let error { self?.renderError = error }
                else { self?.renderedFrames += 1 }
            }
        }
        command.commit()
    }
}
