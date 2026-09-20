import SwiftUI
import CoreImage

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @StateObject private var status = RuntimeStatus()
    @State private var simulatedAngle = 105.0
    @State private var followLid = false
    @State private var previewReferenceAngle = 110.0
    @State private var appearancePreview: Double?
    @State private var simulation = LidPreviewDriver()
    @State private var simulatedProgress = 0.0
    @State private var demoStarted: Date?
    @State private var demoReference = 110.0
    @State private var independentPreview = false
    @State private var previewPaused = false
    @State private var tutorialStep: SettingsTutorialStep?
    @AccessibilityFocusState private var tutorialFocus: SettingsTutorialStep?
    private let previewClock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()
    @State private var showCompatibility = false
    var isPreferencePane = false
    var onCommand: ((String) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.42, green: 0.76, blue: 0.68) : Color(red: 0.14, green: 0.48, blue: 0.43)
    }
    private var captureLabel: String {
        switch status.captureState {
        case .ready: return "Screen access · verified"
        case .checking: return "Screen access · checking"
        case .unavailable: return "Screen access · unavailable"
        case .unverified: return "Screen access · not checked"
        case .needsPermission: return "Screen access · not verified"
        }
    }
    private var usesLiveLid: Bool { followLid && !independentPreview }
    private var angle: Double { usesLiveLid ? (status.angle ?? simulatedAngle) : simulatedAngle }
    private var progress: Double {
        if let appearancePreview { return appearancePreview }
        if usesLiveLid && preferences.settings.enabled && status.permission { return status.progress }
        return simulatedProgress
    }

    @State private var selectedTab = SettingsTab.appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        settingsSurface
        .frame(width: 610, height: 780)
        .background(SettingsBackdrop())
        .tint(accent)
        .onAppear {
            resetPreview()
            if !preferences.hasCompletedSettingsTutorial { startTutorial() }
        }
        .onReceive(previewClock) { date in updatePreview(at: date) }
        .onDisappear { demoStarted = nil }
        .onChange(of: followLid) { _, following in
            if following {
                previewReferenceAngle = status.angle ?? 110
                sendCommand("calibrate")
            }
            resetPreview()
        }
        .onChange(of: status.angle) { old, new in
            if usesLiveLid && old != new { appearancePreview = nil }
        }
        .onChange(of: preferences.settings.clearAtAngle) { _, _ in pauseForSettingsEdit() }
        .onChange(of: preferences.settings.adjustmentAllowance) { _, _ in pauseForSettingsEdit() }
        .onChange(of: preferences.settings.automaticStart) { _, _ in pauseForSettingsEdit() }
        .onChange(of: preferences.settings.nearClosedAngle) { _, _ in pauseForSettingsEdit() }
        .onChange(of: preferences.settings.holdWhenStill) { _, _ in pauseForSettingsEdit() }
        .onChange(of: preferences.settings.duoStyle) { _, _ in showAppearancePreview() }
        .onChange(of: preferences.settings.progressiveBlur) { _, _ in showAppearancePreview() }
        .onChange(of: selectedTab) { _, tab in
            if tutorialStep != nil,
               let step = SettingsTutorialStep.allCases.first(where: { $0.tab == tab }) {
                selectTutorialStep(step)
            }
        }
        .onChange(of: preferences.hasCompletedSettingsTutorial) { _, completed in
            if completed { tutorialStep = nil }
        }
        .sheet(isPresented: $showCompatibility) {
            CompatibilityView(angle: status.angle, running: status.running, permission: status.permission)
        }
    }


    @ViewBuilder private var settingsSurface: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 18) { settingsLayout }
        } else {
            settingsLayout
        }
    }

    private var settingsLayout: some View {
        VStack(spacing: 16) {
            header
            previewPanel
            Picker("Settings section", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
            .controlSize(.large)
            .accessibilityLabel("Settings section")

            if let tutorialStep {
                tutorialCard(tutorialStep)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .appearance: appearanceControls
                    case .lid: lidControls
                    case .general: generalControls
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .id(selectedTab)
                .transition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: selectedTab)
            .frame(maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tutorialStep)
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: BrandArtwork.icon).resizable().interpolation(.high)
                    .frame(width: 38, height: 38).accessibilityLabel("cf. app icon")
                VStack(alignment: .leading, spacing: 2) {
                    Text("cladofold.").font(.system(size: 23, weight: .medium))
                    Text("A softer close. A clearer open.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { startTutorial() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show quick tour")
                .help("Show quick tour")
                Toggle("Enable cladofold.", isOn: $preferences.settings.enabled)
                    .labelsHidden().toggleStyle(.switch)
                    .accessibilityLabel("Enable cladofold.")
            }
            HStack(spacing: 7) {
                Image(systemName: status.ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(status.ready ? accent : Color.orange)
                Text(status.ready ? "Ready" : (status.running ? status.message : "Start cladofold. to connect."))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !status.ready {
                    Button(status.running ? "Review setup" : "Start cladofold.") {
                        if status.running { selectedTab = .general } else { sendCommand("start") }
                    }.controlSize(.small)
                } else if let angle = status.angle {
                    Text("Lid · \(Int(angle))°").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tutorialCard(_ step: SettingsTutorialStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick tour · \(step.rawValue + 1) of \(SettingsTutorialStep.allCases.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(step.title).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(step.message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 10) {
                Button("Skip tutorial") { finishTutorial() }
                    .buttonStyle(.link).font(.caption)
                HStack(spacing: 8) {
                    if step != .appearance {
                        Button("Back") { showTutorialStep(step.rawValue - 1) }
                    }
                    Button(step == .general ? "Done" : "Next") {
                        if step == .general { finishTutorial() }
                        else { showTutorialStep(step.rawValue + 1) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .modifier(SettingsGlass(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick tour, step \(step.rawValue + 1) of \(SettingsTutorialStep.allCases.count): \(step.title). \(step.message)")
        .accessibilityFocused($tutorialFocus, equals: step)
    }

    private var previewPanel: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                FoldPreview(progress: progress, settings: preferences.settings)
                    .frame(width: 255, height: 143)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .padding(4)
                    .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(alignment: .bottom) {
                        Capsule().fill(.gray.opacity(0.6)).frame(width: 280, height: 4).offset(y: 5)
                    }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview").font(.headline)
                    Text(previewPaused ? "Paused · \(Int(angle))°" : (demoStarted != nil ? "Playing · \(Int(angle))°" : (appearancePreview == nil ? "\(Int(angle))°" : "Appearance preview")))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                    Button(demoStarted == nil ? "Play preview" : "Stop preview") {
                        if demoStarted == nil { playPreview() } else { demoStarted = nil }
                    }.buttonStyle(.bordered).controlSize(.small)
                    if appearancePreview != nil || independentPreview || demoStarted != nil {
                        Button(followLid ? "Return to lid" : "Reset preview") { resetPreview() }
                            .buttonStyle(.link).font(.caption)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer").foregroundStyle(.secondary)
                Slider(value: Binding(get: { angle }, set: { next in
                    if usesLiveLid { resetSimulation(angle: angle, time: Date().timeIntervalSinceReferenceDate) }
                    if previewPaused {
                        resetSimulation(angle: max(angle, simulation.motion.openAngle ?? angle), time: Date().timeIntervalSinceReferenceDate)
                        previewPaused = false
                    }
                    demoStarted = nil
                    independentPreview = true
                    appearancePreview = nil
                    simulatedAngle = next
                }), in: 0...150).accessibilityLabel("Preview lid angle")
                Text("\(Int(angle))°").font(.caption).monospacedDigit().frame(width: 34, alignment: .trailing)
            }
            HStack {
                Toggle("Follow my lid", isOn: $followLid).disabled(status.angle == nil)
                    .font(.caption)
                Spacer()
                if followLid && preferences.settings.automaticStart {
                    Button("Use current angle as open") {
                        appearancePreview = nil
                        previewReferenceAngle = status.angle ?? previewReferenceAngle
                        resetPreview()
                        sendCommand("calibrate")
                    }.buttonStyle(.link).font(.caption)
                }
                SettingsInfo(title: "Preview", message: "Drag or press Play to try your fold. Follow my lid uses your real screen angle. After changing lid settings, press Play or drag to try again.")
            }
        }
        .padding(18)
        .modifier(SettingsGlass(cornerRadius: 22))
    }

    private var appearanceControls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Presets").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                ForEach(FoldPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        showAppearancePreview()
                        preferences.settings.selectPreset(preset)
                    }
                    .tint(preferences.settings.selectedPreset == preset ? accent : .secondary)
                    .accessibilityAddTraits(preferences.settings.selectedPreset == preset ? .isSelected : [])
                }
            }.buttonStyle(.bordered).controlSize(.small)
            HStack {
                if let selected = preferences.settings.selectedPreset {
                    Text(preferences.settings.presetIsModified ? "\(selected.rawValue) · Edited" : "\(selected.rawValue) · Default")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save as \(selected.rawValue) default") { preferences.settings.savePresetDefault() }
                        .disabled(!preferences.settings.presetIsModified)
                    if preferences.settings.presetDefaults[selected.rawValue] != nil {
                        Button("Restore original") {
                            showAppearancePreview()
                            preferences.settings.restoreOriginalPreset()
                        }
                    }
                } else {
                    Text("Custom look")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu("Save current look as…") {
                        ForEach(FoldPreset.allCases) { preset in
                            Button("\(preset.rawValue) default") {
                                var value = preferences.settings
                                value.selectedPreset = preset
                                value.savePresetDefault()
                                preferences.settings = value
                            }
                        }
                    }.menuStyle(.borderlessButton).fixedSize()
                }
            }.buttonStyle(.link).controlSize(.small)
            Divider()
            settingToggle("Duo fold animation", value: $preferences.settings.duoStyle, help: "Make the screen look like it folds shut. Turn off for blur only.")
            settingSlider("Dark border", value: $preferences.settings.borderDepth, range: 0...1.5, display: "\(Int(preferences.settings.borderDepth * 100))%", previewsAppearance: true, help: "Choose how wide the dark edges look. Needs Duo fold animation.")
                .disabled(!preferences.settings.duoStyle)
            settingSlider("Maximum blur", value: $preferences.settings.radius, range: 0...80, display: "\(Int(preferences.settings.radius)) pt", previewsAppearance: true, help: "Set the strongest blur used by the fold.")
            settingSlider("Darkening", value: $preferences.settings.dimming, range: 0...0.65, display: "\(Int(preferences.settings.dimming * 100))%", previewsAppearance: true, help: "Choose how dark the screen gets as it folds.")
            settingToggle("Progressive blur", value: $preferences.settings.progressiveBlur, help: "Make the top blurrier than the bottom. Turn off for even blur.")
        }
    }

    private var lidControls: some View {
        VStack(spacing: 14) {
            settingSlider("Smoothing", value: $preferences.settings.smoothing, range: BlurSettings.smoothingRange, display: "\(Int((preferences.settings.smoothing * 1000).rounded())) ms", help: "Lower feels quicker; higher feels softer. Starts right away in both directions. Default: 378 ms.", step: 0.001)
            Divider()
            settingToggle("Start when closing", value: $preferences.settings.automaticStart, help: "Start from wherever your lid is resting. Turn off to choose a fixed starting angle.")
            if preferences.settings.automaticStart {
                settingSlider("Clear when opened to", value: $preferences.settings.clearAtAngle, range: 40...130, display: "\(Int(preferences.settings.clearAtAngle))°", help: "Clear the screen when you reopen this far, or reach your starting angle if it was lower.", step: 1)
                settingSlider("Adjustment allowance", value: $preferences.settings.adjustmentAllowance, range: 3...15, display: "\(Int(preferences.settings.adjustmentAllowance))°", help: "Adjust your screen this far without folding. Close farther to start. Hold any closing position for one second to make it your new clear position.", step: 1)
                settingSlider(preferences.settings.duoStyle ? "Black at" : "Full blur at", value: $preferences.settings.nearClosedAngle, range: 0...30, display: "\(Int(preferences.settings.nearClosedAngle))°", help: "Finish the fold at this lid angle. Zero means fully shut.", step: 1)
            } else {
                settingSlider("Begin below", value: $preferences.settings.startAngle, range: 35...130, display: "\(Int(preferences.settings.startAngle))°", help: "Start the manual fold below this angle.", step: 1)
                settingSlider("Full blur at", value: $preferences.settings.endAngle, range: 0...(preferences.settings.startAngle - 10), display: "\(Int(preferences.settings.endAngle))°", help: "Finish the fold at this lid angle.", step: 1)
            }
            settingToggle("Hold partial folds", value: $preferences.settings.holdWhenStill, help: preferences.settings.automaticStart ? "Keep the fold during short pauses and while reopening. Hold still briefly at a closing position to make it your new clear position. Turn off to readjust after half a second." : "Keep the blur when you pause. Turn off to clear after a half-second pause.")
        }
    }

    private var generalControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingToggle("Launch at login", value: $preferences.settings.launchAtLogin, help: "Start cladofold. automatically when you sign in to your Mac.")
            githubStarCard
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Screen access").font(.headline)
                Text(captureLabel).font(.callout).foregroundStyle(.secondary)
                if !status.permission {
                    Text(status.captureState == .unavailable
                         ? "Keep the built-in display awake and unlocked, then check again. If the problem remains, quit and reopen cladofold."
                         : "Enable cladofold. in Screen Recording, accept Quit & Reopen if macOS asks, then choose Check again.")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    if status.captureState == .needsPermission {
                        Text("If it is already enabled, quit and reopen cladofold. If access is still denied, remove the old entry and add the installed app again.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } else if status.captureState == .unverified {
                        Text("First time here? Open Screen Recording and enable cladofold. Complete your Mac’s authentication and Quit & Reopen if asked.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Button("Open Screen Recording…") { sendCommand("permission") }
                        Button("Check again") { sendCommand("recheck") }
                    }.disabled(status.captureState == .checking)
                }
                Text("One temporary frame per fold. Never saved or sent.").font(.caption).foregroundStyle(.secondary)
                Button(status.previewing ? "Stop desktop preview" : "Preview on my screen") {
                    sendCommand(status.previewing ? "stopPreview" : "preview")
                }.disabled(!status.permission)
            }
            Divider()
            HStack {
                Button("Check Mac compatibility…") { showCompatibility = true }
                Spacer()
                if !isPreferencePane {
                    Button("Open in System Settings") { sendCommand("systemSettings") }
                }
            }.controlSize(.small)
            HStack {
                Text(status.shortcutAvailable ? "⌃⌥⌘B disables the effect instantly." : "Shortcut unavailable. Disable the effect from the menu bar.")
                    .font(.caption).foregroundStyle(status.shortcutAvailable ? Color.secondary : .orange)
                Spacer()
                Button("Reset settings") { preferences.settings = BlurSettings() }
                    .controlSize(.small)
            }
            Text("Built-in display only. Screen previews end after 6 seconds. macOS controls sleep and the lock screen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var githubStarCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "star")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Help cladofold. grow")
                    .font(.callout.weight(.medium))
                Text("A GitHub star helps more people find the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Link(destination: CladofoldID.repositoryURL) {
                HStack(spacing: 6) {
                    Text("Star on GitHub")
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Opens the cladofold. repository in your default browser")
        }
        .padding(14)
        .modifier(SettingsGlass(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func settingToggle(_ title: String, value: Binding<Bool>, help: String) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.callout)
            SettingsInfo(title: title, message: help)
            Spacer()
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel(title)
        }
    }

    private func sendCommand(_ command: String) {
        if let onCommand { onCommand(command) } else { status.command(command) }
    }

    private func startTutorial() {
        showTutorialStep(SettingsTutorialStep.appearance.rawValue)
    }

    private func showTutorialStep(_ index: Int) {
        guard SettingsTutorialStep.allCases.indices.contains(index) else { return }
        selectTutorialStep(SettingsTutorialStep.allCases[index])
    }

    private func selectTutorialStep(_ step: SettingsTutorialStep) {
        tutorialStep = step
        selectedTab = step.tab
        DispatchQueue.main.async { tutorialFocus = step }
    }

    private func finishTutorial() {
        tutorialFocus = nil
        tutorialStep = nil
        preferences.completeSettingsTutorial()
    }

    private func showAppearancePreview() {
        demoStarted = nil
        appearancePreview = LidPreviewMath.appearanceProgress(from: progress)
    }

    private func resetPreview() {
        demoStarted = nil
        previewPaused = false
        independentPreview = false
        appearancePreview = nil
        simulatedAngle = min(150, max(110, preferences.settings.clearAtAngle + 10))
        resetSimulation(angle: angle, time: Date().timeIntervalSinceReferenceDate)
    }

    private func playPreview() {
        previewPaused = false
        independentPreview = true
        appearancePreview = nil
        demoReference = min(150, max(110, preferences.settings.clearAtAngle + 10))
        simulatedAngle = demoReference
        let now = Date()
        resetSimulation(angle: demoReference, time: now.timeIntervalSinceReferenceDate)
        demoStarted = now
    }

    private func updatePreview(at date: Date) {
        // Live mode already uses desktop progress. Mutating the unused @State
        // simulation here used to relayout every glass control at 60 Hz.
        guard !previewPaused, !(usesLiveLid && preferences.settings.enabled && status.permission), appearancePreview == nil else { return }
        if let started = demoStarted {
            let elapsed = date.timeIntervalSince(started)
            let end = preferences.settings.automaticStart ? preferences.settings.nearClosedAngle : preferences.settings.endAngle
            simulatedAngle = LidPreviewMath.demoAngle(elapsed: elapsed, reference: demoReference, closed: end)
            if elapsed >= LidPreviewMath.demoDuration { demoStarted = nil }
        }
        if simulation.update(angle: angle, time: date.timeIntervalSinceReferenceDate, settings: preferences.settings) {
            simulatedProgress = simulation.progress
        }
    }

    private func resetSimulation(angle: Double, time: Double) {
        simulation.reset(angle: angle, time: time)
        simulatedProgress = 0
    }

    private func pauseForSettingsEdit() {
        let currentAngle = angle
        let currentProgress = progress
        demoStarted = nil
        independentPreview = true
        simulatedAngle = currentAngle
        appearancePreview = currentProgress
        previewPaused = true
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String, previewsAppearance: Bool = false, help: String, step: Double? = nil) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(title).font(.callout)
                SettingsInfo(title: title, message: help)
                Spacer()
                Text(display).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
            }
            let binding = Binding<Double>(get: { value.wrappedValue }, set: { next in
                if previewsAppearance { showAppearancePreview() }
                value.wrappedValue = next
            })
            if let step {
                Slider(value: binding, in: range, step: step).accessibilityLabel(title)
            } else {
                Slider(value: binding, in: range).accessibilityLabel(title)
            }
        }
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
