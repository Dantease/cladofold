import SwiftUI
import CoreImage

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @StateObject private var status = RuntimeStatus()
    @State private var simulatedAngle = 105.0
    @State private var followLid = false
    @State private var previewReferenceAngle = 110.0
    @State private var appearancePreview: Double?
    @State private var revealStarted: Date?
    @State private var revealTask: Task<Void, Never>?
    @State private var showCompatibility = false
    var isPreferencePane = false
    var onCommand: ((String) -> Void)? = nil
    private let accent = Color(red: 0.14, green: 0.48, blue: 0.43)
    private var captureLabel: String {
        switch status.captureState {
        case .ready: return "Screen access · verified"
        case .checking: return "Screen access · checking"
        case .unavailable: return "Screen access · unavailable"
        case .unverified: return "Screen access · not checked"
        case .needsPermission: return "Screen access · not verified"
        }
    }
    private var angle: Double { followLid ? (status.angle ?? simulatedAngle) : simulatedAngle }
    private var progress: Double {
        if let appearancePreview { return appearancePreview }
        if followLid && preferences.settings.enabled { return status.progress }
        return LidPreviewMath.progress(angle: angle, reference: followLid ? previewReferenceAngle : 110, settings: preferences.settings)
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: status.ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(status.ready ? accent : Color.orange)
                        Text(status.running ? status.message : "Start cladofold. to check your setup.")
                            .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if !status.running { Button("Start cladofold.") { sendCommand("start") } }
                    }
                    HStack(spacing: 16) {
                        Label(status.angle.map { "Lid sensor · \(Int($0))° live" } ?? "Lid sensor · waiting", systemImage: "laptopcomputer")
                        Label(captureLabel, systemImage: "rectangle.dashed.badge.record")
                    }.font(.caption).foregroundStyle(.secondary)
                    if status.running && !status.permission {
                        Text(status.captureState == .unavailable ? "Keep the built-in display awake and unlocked, then check again. If the problem remains, quit and reopen cladofold." : "Already allowed screen access? Choose Check again. If macOS still cannot authorize this copy, quit and reopen the installed app. Automatic retries pause after a failed check.")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Text("Frames stay in memory on your Mac and are discarded when the effect clears.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if status.captureState != .unavailable {
                                Button("Open Screen Recording…") { sendCommand("permission") }
                            }
                            Button("Check again") { sendCommand("recheck") }
                        }.disabled(status.captureState == .checking)
                        if status.captureState == .needsPermission {
                            Text("An updated preview can leave an older permission entry behind. If restarting does not help, remove only cladofold.’s old entry and add the installed app again in Screen & System Audio Recording.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        } else if status.captureState == .unverified {
                            Text("First time here? Open Screen Recording and enable cladofold. Complete your Mac’s authentication and Quit & Reopen if asked.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if status.running && status.angle == nil {
                        Button("Check sensor compatibility…") { showCompatibility = true }.buttonStyle(.link)
                    }
                }.padding(14).background((status.ready ? accent : Color.orange).opacity(0.065), in: RoundedRectangle(cornerRadius: 11))

                VStack(spacing: 12) {
                    HStack {
                        Label("LID PREVIEW", systemImage: "viewfinder").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(1.4)
                        Spacer()
                        Text(revealStarted != nil ? "Vacuum reveal preview" : (appearancePreview == nil ? "\(Int(angle))°" : "Appearance preview"))
                            .font(.system(.body, design: .monospaced)).foregroundStyle(accent)
                    }.foregroundStyle(.secondary)
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: revealStarted == nil)) { timeline in
                      let progress = revealStarted.map { LidPreviewMath.revealProgress(elapsed: timeline.date.timeIntervalSince($0)) } ?? self.progress
                      HStack(spacing: 25) {
                        FoldPreview(progress: progress, settings: preferences.settings)
                        .frame(width: 255, height: 143).clipShape(RoundedRectangle(cornerRadius: 7))
                        .padding(5).background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(alignment: .bottom) { Capsule().fill(Color.gray).frame(width: 290, height: 5).offset(y: 6) }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(progress < 0.01 ? "Crystal clear" : "\(Int(progress * 100))% folded").font(.system(size: 17, weight: .medium))
                            Text(preferences.settings.vacuumReveal ? "Close to draw the image toward the hinge. Open to reveal it slowly from the bottom." : "Close to draw the image into soft dark borders. Open to bring it back into focus.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.vertical, 5)
                    }
                    HStack {
                        Image(systemName: "laptopcomputer").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { simulatedAngle }, set: { stopRevealPreview(); appearancePreview = nil; simulatedAngle = $0 }), in: 0...130)
                            .disabled(followLid).accessibilityLabel("Preview lid angle")
                        Text("\(Int(angle))°").monospacedDigit().frame(width: 35, alignment: .trailing)
                    }
                    HStack {
                        Toggle("Follow my lid", isOn: $followLid).disabled(status.angle == nil)
                        Spacer()
                        if appearancePreview != nil || revealStarted != nil {
                            Button(followLid ? "Return to lid" : "Return to angle") { stopRevealPreview(); appearancePreview = nil }
                                .buttonStyle(.link).font(.caption)
                        } else {
                            Text(followLid ? "Your starting angle is the clear position." : "Drag to try it without moving your Mac.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if preferences.settings.vacuumReveal {
                        Button("Replay vacuum reveal") { playRevealPreview() }.buttonStyle(.link).font(.caption)
                    }
                    if followLid && preferences.settings.automaticStart {
                        Button("Use current angle as open") {
                            stopRevealPreview()
                            appearancePreview = nil
                            previewReferenceAngle = status.angle ?? previewReferenceAngle
                            sendCommand("calibrate")
                        }.buttonStyle(.link).font(.caption)
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
                    Toggle("Vacuum reveal", isOn: $preferences.settings.vacuumReveal)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    settingSlider("Dark border", value: $preferences.settings.borderDepth, range: 0...1.5, display: "\(Int(preferences.settings.borderDepth * 100))%", previewsAppearance: true)
                        .disabled(!preferences.settings.duoStyle)
                    settingSlider("Maximum blur", value: $preferences.settings.radius, range: 0...80, display: "\(Int(preferences.settings.radius)) pt", previewsAppearance: true)
                    settingSlider("Darkening", value: $preferences.settings.dimming, range: 0...0.65, display: "\(Int(preferences.settings.dimming * 100))%", previewsAppearance: true)
                    Toggle("Progressive blur from the hinge", isOn: $preferences.settings.progressiveBlur)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    Divider().padding(.horizontal, 13)
                    Toggle("Start when I begin closing", isOn: $preferences.settings.automaticStart)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).padding(.vertical, 8)
                    if preferences.settings.automaticStart {
                        Text((status.openAngle.map { "Following your \(Int($0))° open position." } ?? "Follows the open position you start from.") + " Ignores tiny movements: starts 3° below open and clears within 1°.")
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
        .onChange(of: followLid) { _, following in
            stopRevealPreview()
            appearancePreview = nil
            if following {
                previewReferenceAngle = status.angle ?? 110
                sendCommand("calibrate")
            }
        }
        .onChange(of: status.angle) { old, new in
            if followLid && old != new { appearancePreview = nil }
        }
        .onChange(of: preferences.settings.duoStyle) { _, _ in showAppearancePreview() }
        .onChange(of: preferences.settings.progressiveBlur) { _, _ in showAppearancePreview() }
        .onChange(of: preferences.settings.vacuumReveal) { _, enabled in
            if enabled { playRevealPreview() }
            else { stopRevealPreview(); showAppearancePreview() }
        }
        .onDisappear { stopRevealPreview() }
        .sheet(isPresented: $showCompatibility) {
            CompatibilityView(angle: status.angle, running: status.running, permission: status.permission)
        }
    }

    private func preset(_ radius: Double, _ dimming: Double, _ smoothing: Double) {
        showAppearancePreview()
        var value = preferences.settings
        value.radius = radius; value.dimming = dimming; value.smoothing = smoothing
        preferences.settings = value
    }

    private func sendCommand(_ command: String) {
        if let onCommand { onCommand(command) } else { status.command(command) }
    }

    private func showAppearancePreview() {
        stopRevealPreview()
        appearancePreview = LidPreviewMath.appearanceProgress(from: progress)
    }

    private func stopRevealPreview() {
        revealTask?.cancel()
        revealTask = nil
        revealStarted = nil
    }

    private func playRevealPreview() {
        stopRevealPreview()
        appearancePreview = nil
        revealStarted = Date()
        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            revealStarted = nil
            appearancePreview = 0
            revealTask = nil
        }
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String, previewsAppearance: Bool = false) -> some View {
        HStack(spacing: 15) {
            Text(title).frame(width: 112, alignment: .leading)
            Slider(value: Binding(get: { value.wrappedValue }, set: { next in
                if previewsAppearance { showAppearancePreview() }
                value.wrappedValue = next
            }), in: range).accessibilityLabel(title)
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
        view.setAccessibilityLabel("Lid preview, \(Int(progress * 100)) percent folded, \(Int(settings.radius)) point maximum blur")
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
