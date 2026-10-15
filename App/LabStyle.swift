import SwiftUI
import BatteryCore

enum LabStyle {
    static let background = Color(red: 0.018, green: 0.027, blue: 0.055)
    static let panel = Color(red: 0.043, green: 0.061, blue: 0.093)
    static let cyan = Color(red: 0.34, green: 0.94, blue: 0.94)
    static let violet = Color(red: 0.69, green: 0.57, blue: 1)
    static let amber = Color(red: 1, green: 0.75, blue: 0.39)
    static let muted = Color(red: 0.62, green: 0.70, blue: 0.80)
    static let ink = Color(red: 0.93, green: 0.97, blue: 1)
    static func accent(_ preset: CellPreset) -> Color {
        switch preset.accent.rawValue {
        case "violet", "purple": violet
        case "amber", "orange": amber
        case "green", "mint", "lime": Color(red: 0.47, green: 0.94, blue: 0.68)
        case "pink", "rose", "coral": Color(red: 1, green: 0.48, blue: 0.68)
        case "indigo": violet
        case "blue": Color(red: 0.4, green: 0.65, blue: 1)
        default: cyan
        }
    }
    static func symbol(_ preset: CellPreset) -> String {
        switch preset.formFactor.rawValue {
        case "nano": "atom"
        case "thinFilm": "square.stack.3d.up"
        case "coin": "circle.circle"
        case "pack": "square.grid.3x3"
        case "flow": "arrow.triangle.2.circlepath"
        case "prismatic": "rectangle.portrait.split.2x1"
        case "pouch": "rectangle.portrait"
        default: "battery.100percent"
        }
    }
}

struct LabPanel<Content: View>: View {
    var title: String
    var icon: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).foregroundStyle(LabStyle.cyan) }
                Text(title.uppercased()).font(.system(.caption, design: .monospaced, weight: .semibold)).tracking(1.4)
            }.foregroundStyle(LabStyle.muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LabStyle.panel, in: .rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.075)))
    }
}

struct LabScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .frame(maxWidth: 760).padding(.horizontal, 20).padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }.background(LabStyle.background).foregroundStyle(LabStyle.ink)
            .toolbarBackground(LabStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct GlassControlStyle: ButtonStyle {
    var prominent = false
    var tint = LabStyle.cyan
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        let content = configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 15).frame(minHeight: 46)
            .contentShape(Capsule())
            .foregroundStyle(prominent ? LabStyle.background : tint)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.35)
        if reduceTransparency {
            content.background(prominent ? tint : LabStyle.panel, in: .capsule)
        } else {
            content.glassEffect(.regular.tint(prominent ? tint : tint.opacity(0.08)).interactive(isEnabled), in: .capsule)
        }
    }
}

struct Readout: View {
    var title: String
    var value: String
    var tint = LabStyle.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(0.8).foregroundStyle(LabStyle.muted)
            Text(value).font(.system(.title3, design: .monospaced, weight: .medium))
                .monospacedDigit().foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

struct ValueSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var formatted: String
    var footnote: String? = nil
    var tint = LabStyle.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(formatted).font(.system(.subheadline, design: .monospaced)).monospacedDigit().foregroundStyle(tint)
            }
            Slider(value: $value, in: range).tint(tint).accessibilityLabel(title).accessibilityValue(formatted)
            if let footnote { Text(footnote).font(.caption).foregroundStyle(LabStyle.muted).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

func quantity(_ value: Double, _ unit: String) -> String {
    guard value.isFinite else { return "—" }
    if value == 0 { return "0 \(unit)" }
    for (scale, prefix) in [(1e9,"G"),(1e6,"M"),(1e3,"k"),(1.0,""),(1e-3,"m"),(1e-6,"µ"),(1e-9,"n"),(1e-12,"p")] {
        if abs(value) >= scale { return String(format: "%.3g %@%@", value / scale, prefix, unit) }
    }
    return String(format: "%.2g %@", value, unit)
}

func durationText(_ seconds: Double) -> String {
    if seconds < 60 { return String(format: "%.0f s", seconds) }
    if seconds < 3600 { return String(format: "%.1f min", seconds / 60) }
    if seconds < 86400 { return String(format: "%.2f h", seconds / 3600) }
    return String(format: "%.1f days", seconds / 86400)
}
