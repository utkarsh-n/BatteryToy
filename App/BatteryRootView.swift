import SwiftUI
import BatteryCore

enum BatteryTab: Hashable { case lab, atlas, compare }
enum LabSheet: String, Identifiable { case specimens, physics, light; var id: String { rawValue } }

struct BatteryRootView: View {
    var lab: BatteryLab
    @State private var tab: BatteryTab = .lab
    @State private var motion = MotionLight()
    @State private var sheet: LabSheet?
    @AppStorage("BatteryToy.motion") private var motionEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TabView(selection: $tab) {
            Tab("Lab", systemImage: "cube.transparent", value: .lab) {
                NavigationStack {
                    BatteryBench(lab: lab, motion: motion, showSheet: { sheet = $0 })
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Text("BATTERY TOY").font(.system(.caption, design: .monospaced, weight: .medium)).tracking(2.5).foregroundStyle(LabStyle.muted)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Light & motion", systemImage: "gyroscope") { sheet = .light }
                            }
                        }
                }
            }
            Tab("Atlas", systemImage: "square.grid.2x2", value: .atlas) {
                NavigationStack {
                    AtlasView(lab: lab, openLab: { tab = .lab })
                }
            }
            Tab("Compare", systemImage: "chart.xyaxis.line", value: .compare) {
                NavigationStack { CompareView() }
            }
        }
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .specimens: SpecimenPicker(lab: lab)
                case .physics: PhysicsView(preset: lab.preset)
                case .light: LightSettings(motion: motion, enabled: $motionEnabled)
                }
            }.preferredColorScheme(.dark)
        }
        .task(id: shouldSenseMotion) {
            if shouldSenseMotion { motion.start() } else { motion.stop() }
        }
        .task(id: shouldTick) {
            guard shouldTick else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                let now = clock.now
                let interval = previous.duration(to: now)
                previous = now
                let seconds = Double(interval.components.seconds) + Double(interval.components.attoseconds) / 1e18
                lab.tick(realSeconds: seconds)
            }
        }
        .onDisappear { motion.stop() }
    }
    private var shouldSenseMotion: Bool { scenePhase == .active && tab == .lab && motionEnabled && !reduceMotion && sheet == nil }
    private var shouldTick: Bool { scenePhase == .active && lab.running }
}

struct LightSettings: View {
    var motion: MotionLight
    @Binding var enabled: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Form {
            Section {
                Toggle("Tilt-driven light", isOn: $enabled)
                Button("Recenter the reflection") { motion.recenter() }
            } footer: {
                Text(reduceMotion ? "Reduce Motion is enabled. The hologram stays still." : "Move the phone gently to shift the highlight, color fringe, and perspective. You can also drag the cell to inspect it.")
            }
            Section("Optics") {
                Text("The reflection is a real-time visual response to device attitude. The hologram uses a stylized refraction effect; it does not solve the optical properties of a physical battery.")
            }
        }.navigationTitle("Light & motion")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
