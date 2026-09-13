import SwiftUI
import CoreImage

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @StateObject private var status = RuntimeStatus()
    @State private var simulatedAngle = 105.0
    @State private var followLid = false
    @State private var showCompatibility = false
    var isPreferencePane = false
    var onCommand: ((String) -> Void)? = nil
    private let accent = Color(red: 0.14, green: 0.48, blue: 0.43)
    private var angle: Double { followLid ? (status.angle ?? simulatedAngle) : simulatedAngle }
    private var progress: Double {
        if followLid { return status.progress }
        if preferences.settings.automaticStart {
            var motion = LidMotion()
            _ = motion.target(angle: 110, time: 0, settings: preferences.settings)
            return motion.target(angle: angle, time: 0.1, settings: preferences.settings)
        }
        return BlurMath.progress(angle: angle, settings: preferences.settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    Image(nsImage: BrandArtwork.icon).resizable().interpolation(.high)
                        .frame(width: 60, height: 60).accessibilityLabel("cf. app icon")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("cladofold.").font(.system(size: 25, weight: .semibold))
                        Text("A softer close. A clearer open.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Enable cladofold.", isOn: $preferences.settings.enabled)
                        .labelsHidden().toggleStyle(.switch).tint(accent)
                        .accessibilityLabel("Enable cladofold.")
                }

                VStack(spacing: 12) {
                    HStack {
                        Label("LID PREVIEW", systemImage: "viewfinder").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(1.4)
                        Spacer()
                        Text("\(Int(angle))°").font(.system(.body, design: .monospaced)).foregroundStyle(accent)
                    }.foregroundStyle(.secondary)
                    HStack(spacing: 25) {
                        FoldPreview(progress: progress, settings: preferences.settings)
                        .frame(width: 255, height: 143).clipShape(RoundedRectangle(cornerRadius: 7))
                        .padding(5).background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(alignment: .bottom) { Capsule().fill(Color.gray).frame(width: 290, height: 5).offset(y: 6) }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(progress < 0.01 ? "Crystal clear" : "\(Int(progress * 100))% folded").font(.system(size: 17, weight: .medium))
                            Text("Close to draw the image into soft dark borders. Open to bring it back into focus.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.vertical, 5)
                    HStack {
                        Image(systemName: "laptopcomputer").foregroundStyle(.secondary)
                        Slider(value: $simulatedAngle, in: 0...130).disabled(followLid).accessibilityLabel("Preview lid angle")
                        Text("\(Int(simulatedAngle))°").monospacedDigit().frame(width: 35, alignment: .trailing)
                    }
                    HStack {
                        Toggle("Follow my lid", isOn: $followLid).disabled(status.angle == nil)
                        Spacer()
                        Text("Drag to try it without moving your Mac.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(17).background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))

                VStack(spacing: 0) {
                    HStack {
                        Text("Blur strength")
                        Spacer()
                        Button("Duo") {
                            preset(48, 0.12, 0.075)
                            preferences.settings.duoStyle = true
                            preferences.settings.progressiveBlur = true
                            preferences.settings.borderDepth = 1
                        }
                        Button("Subtle") { preset(18, 0.10, 0.08) }
                        Button("Balanced") { preset(36, 0.20, 0.12) }
                        Button("Dreamy") { preset(64, 0.32, 0.22) }
                    }.buttonStyle(.bordered).controlSize(.small).padding(13)
                    Divider().padding(.horizontal, 13)
                    Toggle("Duo fold animation", isOn: $preferences.settings.duoStyle)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    settingSlider("Dark border", value: $preferences.settings.borderDepth, range: 0...1.5, display: "\(Int(preferences.settings.borderDepth * 100))%")
                        .disabled(!preferences.settings.duoStyle)
                    settingSlider("Maximum blur", value: $preferences.settings.radius, range: 0...80, display: "\(Int(preferences.settings.radius)) pt")
                    settingSlider("Darkening", value: $preferences.settings.dimming, range: 0...0.65, display: "\(Int(preferences.settings.dimming * 100))%")
                    Toggle("Progressive blur from the hinge", isOn: $preferences.settings.progressiveBlur)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    Divider().padding(.horizontal, 13)
                    Toggle("Start when I begin closing", isOn: $preferences.settings.automaticStart)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    if preferences.settings.automaticStart {
                        Text(status.openAngle.map { "Following your \(Int($0))° open position." } ?? "Follows the open position you start from.")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13)
                        settingSlider(preferences.settings.duoStyle ? "Black at" : "Full blur at", value: $preferences.settings.nearClosedAngle, range: 0...30, display: "\(Int(preferences.settings.nearClosedAngle))°")
                        Text(preferences.settings.duoStyle ? "Lid angle above fully closed. Blur begins earlier; full darkness waits until this angle." : "Lid angle above fully closed. The blur reaches its maximum at this angle.")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13)
                    } else {
                        settingSlider("Begin below", value: $preferences.settings.startAngle, range: 35...130, display: "\(Int(preferences.settings.startAngle))°")
                        settingSlider("Full blur at", value: $preferences.settings.endAngle, range: 0...(preferences.settings.startAngle - 10), display: "\(Int(preferences.settings.endAngle))°")
                    }
                    Toggle("Keep blur until I open the lid back up", isOn: $preferences.settings.holdWhenStill)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    if !preferences.settings.holdWhenStill {
                        Text("Clears after the lid stays still for half a second.")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13)
                    }
                    settingSlider("Smoothing", value: $preferences.settings.smoothing, range: 0...0.6, display: "\(Int(preferences.settings.smoothing * 1000)) ms")
                }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.primary.opacity(0.06)))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle().fill(status.running && status.angle != nil ? accent : Color.orange).frame(width: 7, height: 7)
                        Text(status.running ? status.message : "cladofold. is not running").font(.callout)
                        Spacer()
                        if let liveAngle = status.angle { Text("\(Int(liveAngle))° live").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary) }
                        if !status.running { Button("Start cladofold.") { sendCommand("start") } }
                    }
                    if !status.permission {
                        HStack(alignment: .top) {
                            Image(systemName: "rectangle.dashed.badge.record").foregroundStyle(.secondary)
                            Text("Allow Screen Recording to blur your desktop. Frames stay in memory and are discarded when the effect clears.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Button("Allow…") { sendCommand("permission") }
                        }
                    }
                    Divider()
                    Toggle("Launch at login", isOn: $preferences.settings.launchAtLogin)
                    HStack {
                        Button(status.previewing ? "Stop preview" : "Preview on my screen") { sendCommand(status.previewing ? "stopPreview" : "preview") }
                            .disabled(!status.permission)
                        Spacer()
                        Button("Reset settings") { preferences.settings = BlurSettings() }
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(status.shortcutAvailable ? "⌃⌥⌘B instantly disables the effect. Screen preview clears after 6 seconds." : "Shortcut unavailable. Use the cladofold. menu to disable the effect.")
                    Text("Built-in display only. The macOS lock screen stays under system control.")
                    if !isPreferencePane {
                        Button("Open in System Settings ↗") { sendCommand("systemSettings") }.buttonStyle(.link)
                    }
                    Button("Check Mac compatibility…") { showCompatibility = true }.buttonStyle(.link)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(24)
        }
        .frame(width: 610, height: 780)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .sheet(isPresented: $showCompatibility) {
            CompatibilityView(angle: status.angle, running: status.running, permission: status.permission)
        }
    }

    private func preset(_ radius: Double, _ dimming: Double, _ smoothing: Double) {
        var value = preferences.settings
        value.radius = radius; value.dimming = dimming; value.smoothing = smoothing
        preferences.settings = value
    }

    private func sendCommand(_ command: String) {
        if let onCommand { onCommand(command) } else { status.command(command) }
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        HStack(spacing: 15) {
            Text(title).frame(width: 112, alignment: .leading)
            Slider(value: value, in: range).accessibilityLabel(title)
            Text(display).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
        }.padding(.horizontal, 13).padding(.vertical, 8)
    }
}

/// The thumbnail runs the desktop filter on synthetic content, without screen access.
@MainActor private struct FoldPreview: NSViewRepresentable {
    var progress: Double
    var settings: BlurSettings

    func makeNSView(context: Context) -> FoldPreviewImageView {
        let view = FoldPreviewImageView()
        let renderer = ImageRenderer(content: MiniDesktop().frame(width: 255, height: 143))
        renderer.scale = 2
        view.source = renderer.cgImage.map { CIImage(cgImage: $0) }
        view.imageScaling = .scaleAxesIndependently
        return view
    }

    func updateNSView(_ view: FoldPreviewImageView, context: Context) {
        guard view.lastProgress != progress || view.lastSettings != settings, let source = view.source else { return }
        view.lastProgress = progress
        view.lastSettings = settings
        // At 255 points, this is a scale model of an approximately 1512-point display.
        let result = BlurFilter.fold(image: source, progress: progress, settings: settings, pixelsPerPoint: 510.0 / 1512)
        if let cgImage = view.renderer.createCGImage(result, from: source.extent) {
            view.image = NSImage(cgImage: cgImage, size: NSSize(width: 255, height: 143))
        }
    }
}

private final class FoldPreviewImageView: NSImageView {
    let renderer = CIContext(options: [.cacheIntermediates: false])
    var source: CIImage?
    var lastProgress = -1.0
    var lastSettings: BlurSettings?
}

private struct MiniDesktop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.3, blue: 0.29), Color(red: 0.51, green: 0.76, blue: 0.64), Color(red: 0.86, green: 0.84, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Ellipse().fill(.white.opacity(0.18)).frame(width: 270, height: 100).rotationEffect(.degrees(-35)).offset(x: 50, y: 32)
            VStack(spacing: 0) {
                HStack { Image(systemName: "apple.logo"); Text("Finder  File  Edit  View"); Spacer(); Text("9:41") }.font(.system(size: 5, weight: .medium)).padding(5).background(.white.opacity(0.3))
                Spacer()
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 3) { ForEach([Color.red, .yellow, .green], id: \.self) { $0.frame(width: 4, height: 4).clipShape(Circle()) } }
                        Text("Favorites").font(.system(size: 5)).foregroundStyle(.secondary)
                        ForEach(0..<3) { _ in Capsule().fill(.gray.opacity(0.2)).frame(width: 26, height: 3) }
                    }.padding(7).frame(width: 52).frame(maxHeight: .infinity).background(.white.opacity(0.7))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("A little more fluid.").font(.system(size: 9, weight: .semibold))
                        Text("Your Mac, with a softer landing.").font(.system(size: 5))
                        HStack(spacing: 5) { ForEach(0..<3) { n in RoundedRectangle(cornerRadius: 3).fill([Color.teal, Color.orange.opacity(0.7), Color.blue.opacity(0.6)][n]).frame(width: 26, height: 22) } }
                    }.foregroundStyle(.black.opacity(0.8)).padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.white.opacity(0.94))
                }.frame(width: 183, height: 80).clipShape(RoundedRectangle(cornerRadius: 5)).shadow(color: .black.opacity(0.18), radius: 5, y: 4)
                Spacer()
                HStack(spacing: 5) { ForEach(0..<7) { n in RoundedRectangle(cornerRadius: 3).fill([Color.blue, .white, .orange, .green, .gray, .blue, .white][n]).frame(width: 12, height: 12) } }.padding(4).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 5)).padding(.bottom, 4)
            }
        }
    }
}
