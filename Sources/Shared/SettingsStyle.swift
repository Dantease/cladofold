import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case lid = "Lid Behavior"
    case general = "General"
    var id: String { rawValue }
}

enum SettingsTutorialStep: Int, CaseIterable, Identifiable {
    case appearance
    case lid
    case general

    var id: Int { rawValue }
    var tab: SettingsTab {
        switch self {
        case .appearance: return .appearance
        case .lid: return .lid
        case .general: return .general
        }
    }
    var title: String {
        switch self {
        case .appearance: return "Choose your fold"
        case .lid: return "Tune the motion"
        case .general: return "Finish setup"
        }
    }
    var message: String {
        switch self {
        case .appearance: return "Pick a preset, adjust the look, and press Play preview to see the effect here."
        case .lid: return "Choose how softly the fold responds. Hold still briefly at a closing position to make it your new clear position."
        case .general: return "Verify Screen access, then preview the effect on your desktop when you’re ready."
        }
    }
}

struct SettingsGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.primary.opacity(0.35)))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.primary.opacity(0.1)))
        }
    }
}

/// Native translucency, not a simulated glass gradient. Accessibility can opt out.
struct SettingsBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        if reduceTransparency || contrast == .increased {
            Color(nsColor: .windowBackgroundColor)
        } else {
            NativeSettingsBackdrop()
        }
    }
}

private struct NativeSettingsBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct SettingsInfo: View {
    let title: String
    let message: String
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(title)")
        .help("About \(title)")
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(width: 300, alignment: .leading)
        }
    }
}
