import CoreImage
import CoreImage.CIFilterBuiltins

enum BlurFilter {
    /// Hinge-anchored projection onto a fixed image plane. The exposed area is
    /// black and participates in the blur, producing soft, tapered side margins.
    static func fold(image: CIImage, progress: Double, settings: BlurSettings, pixelsPerPoint: Double = 1) -> CIImage {
        let p = BlurSettings.clamp(progress, 0...1, fallback: 0)
        guard p > 0.00001 else { return image }
        guard settings.duoStyle || settings.vacuumReveal else {
            return output(image: image, radius: settings.radius * p * pixelsPerPoint, dimming: settings.dimming * p, progressive: settings.progressiveBlur)
        }
        let bounds = image.extent
        let black = CIImage(color: .black)
        guard p < 1 else { return black.cropped(to: bounds) }

        let tilt = p * Double.pi * 0.48
        let cosine = cos(tilt)
        let depth = 0.26 * settings.borderDepth * sin(tilt)
        let radius = settings.radius * p * pixelsPerPoint
        // Inverse of the viewing-ray intersection with the original screen plane.
        // The bottom edge remains fixed; the image stretches out of the top while
        // the sides pull inward. This stays bounded throughout the closing arc.
        // The old denominator can exceed one near the open end, leaving a black
        // horizontal strip. Keep the projected top beyond the blur's support too.
        let height = settings.vacuumReveal
            ? bounds.height * (1 - 0.92 * pow(p, 1.35))
            : max(bounds.height + max(2, radius * 3), bounds.height / (cosine + depth))
        let inset = settings.vacuumReveal
            ? bounds.width * 0.18 * settings.borderDepth * p
            : bounds.width * 0.5 * depth / (cosine + depth)
        // Optional reveal compresses toward the bottom hinge when closing and
        // grows upward when opening. It shares one reversible curve and renderer
        // with the settings preview; it does not add a delayed desktop overlay.
        let bottomInset = settings.vacuumReveal ? bounds.width * 0.075 * p * p : 0
        let projection = CIFilter.perspectiveTransform()
        projection.inputImage = image
        projection.bottomLeft = CGPoint(x: bounds.minX + bottomInset, y: bounds.minY)
        projection.bottomRight = CGPoint(x: bounds.maxX - bottomInset, y: bounds.minY)
        projection.topLeft = CGPoint(x: bounds.minX + inset, y: bounds.minY + height)
        projection.topRight = CGPoint(x: bounds.maxX - inset, y: bounds.minY + height)
        var projected = (projection.outputImage ?? image).composited(over: black)

        if settings.progressiveBlur && radius > 0.01 {
            let blur = CIFilter.maskedVariableBlur()
            blur.inputImage = projected
            blur.mask = gradient(bounds: bounds, bottom: 0.025, top: 1)
            blur.radius = Float(radius)
            projected = blur.outputImage ?? projected
        } else if radius > 0.01 {
            projected = projected.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
        }
        // Shade the moving outer edge more than the hinge, then finish at black.
        // There is no direction-dependent state: reopening retraces the same image.
        let tail = min(1, max(0, (p - 0.88) / 0.12))
        let closure = 1 - tail * tail * (3 - 2 * tail)
        let hingeLight = (1 - settings.dimming * p) * closure
        let outerLight = hingeLight * (1 - 0.80 * pow(p, 1.15))
        let shade = gradient(bounds: bounds, bottom: hingeLight, top: outerLight)
        return projected.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: shade]).cropped(to: bounds)
    }

    private static func gradient(bounds: CGRect, bottom: Double, top: Double) -> CIImage {
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: bounds.midX, y: bounds.minY)
        gradient.point1 = CGPoint(x: bounds.midX, y: bounds.maxY)
        gradient.color0 = CIColor(red: bottom, green: bottom, blue: bottom)
        gradient.color1 = CIColor(red: top, green: top, blue: top)
        return gradient.outputImage!
    }

    static func output(image: CIImage, radius: Double, dimming: Double, progressive: Bool) -> CIImage {
        var output: CIImage
        if progressive && radius > 0.01 {
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: 0, y: image.extent.minY)
            gradient.point1 = CGPoint(x: 0, y: image.extent.minY + image.extent.height * 0.85)
            gradient.color0 = CIColor(red: 0.2, green: 0.2, blue: 0.2)
            gradient.color1 = CIColor.white
            let blur = CIFilter.maskedVariableBlur()
            blur.inputImage = image.clampedToExtent()
            blur.mask = gradient.outputImage
            blur.radius = Float(radius)
            output = (blur.outputImage ?? image).cropped(to: image.extent)
        } else {
            output = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: image.extent)
        }
        let shade = 1 - dimming
        return output.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: shade, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: shade, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: shade, w: 0)
        ])
    }
}
