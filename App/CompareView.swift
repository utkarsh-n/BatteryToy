import SwiftUI
import Charts
import BatteryCore

struct ComparisonPoint: Identifiable, Sendable {
    let id: Int
    let minutes: Double
    let voltageFraction: Double
    let charge: Double
}
struct ComparisonRun: Sendable {
    var points: [ComparisonPoint]
    var energy: Double
    var peakTemperature: Double
    var endPhase: String
}

struct CompareView: View {
    @State private var firstID = "phone-nmc"
    @State private var secondID = "lfp-prismatic"
    @State private var rate = 0.5
    @State private var temperature = 25.0
    @State private var results: [String: ComparisonRun] = [:]
    @State private var isComputing = false
    @State private var revision = 0
    private var first: CellPreset { CellPreset.all.first { $0.id == firstID } ?? CellPreset.all[0] }
    private var second: CellPreset { CellPreset.all.first { $0.id == secondID } ?? CellPreset.all[1] }
    private var comparisonPresets: [CellPreset] { first.id == second.id ? [first] : [first, second] }
    private var commonMaximum: Double { min(first.model.maxDischargeCRate, second.model.maxDischargeCRate, 2) }
    var body: some View {
        LabScroll {
            VStack(alignment: .leading, spacing: 8) {
                Text("Same load. Different story.").font(.system(.largeTitle, design: .rounded, weight: .medium))
                Text("Compare at the same C-rate. Voltage is normalized to each battery's nominal voltage so a tiny cell and a grid pack share one plot.")
                    .font(.subheadline).foregroundStyle(LabStyle.muted)
            }.padding(.top, 12)
            LabPanel(title: "Two specimens", icon: "arrow.left.arrow.right") {
                presetPicker(title: "A", id: $firstID)
                presetPicker(title: "B", id: $secondID)
                ValueSlider(title: "Discharge rate", value: Binding(get: { log10(rate) }, set: { rate = pow(10, $0) }), range: -4...log10(max(0.0001, commonMaximum)), formatted: String(format: "%.3g C", rate), footnote: "Bounded to the common modeled current envelope")
                ValueSlider(title: "Ambient", value: $temperature, range: -20...45, formatted: String(format: "%.0f °C", temperature), tint: LabStyle.amber)
                Button { compute() } label: { Label(isComputing ? "Simulating…" : "Run comparison", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(GlassControlStyle(prominent: true)).disabled(isComputing).accessibilityIdentifier("run-comparison")
            }
            if !results.isEmpty {
                LabPanel(title: "Voltage under load", icon: "chart.xyaxis.line") {
                    Chart {
                        ForEach(comparisonPresets) { preset in
                            ForEach(results[preset.id]?.points ?? []) { point in
                                LineMark(x: .value("Minutes", point.minutes), y: .value("V / V nominal", point.voltageFraction), series: .value("Battery", preset.name))
                                    .foregroundStyle(by: .value("Battery", preset.name))
                            }
                        }
                    }.chartYAxisLabel("V / V nominal").chartXAxisLabel("Minutes")
                        .chartForegroundStyleScale(domain: comparisonPresets.map(\.name), range: comparisonPresets.count == 1 ? [LabStyle.cyan] : [LabStyle.cyan, LabStyle.violet])
                        .frame(height: 230).accessibilityIdentifier("comparison-chart").accessibilityLabel("Comparison of normalized terminal voltage over simulated minutes")
                    Text("Same C-rate means different amperes and watts. Both start at 100% charge; capacity, cutoff, resistance, and thermal parameters are illustrative.")
                        .font(.caption).foregroundStyle(LabStyle.muted)
                }
                ForEach(comparisonPresets) { preset in
                    if let result = results[preset.id] {
                        LabPanel(title: preset.name, icon: LabStyle.symbol(preset)) {
                            HStack {
                                Readout(title: "Delivered", value: quantity(result.energy, "Wh"))
                                Readout(title: "Peak temp", value: String(format: "%.1f °C", result.peakTemperature), tint: LabStyle.amber)
                            }
                            Text(result.endPhase).font(.caption).foregroundStyle(LabStyle.muted)
                            Text(preset.strengths.first ?? preset.subtitle).font(.subheadline)
                        }
                    }
                }
            } else {
                LabPanel(title: "Try this", icon: "lightbulb") {
                    Text("Compare NMC with LFP: a sloping voltage curve against a long plateau. Then raise the load to reveal voltage sag and heat.").font(.subheadline).foregroundStyle(LabStyle.muted)
                }
            }
        }.navigationTitle("Compare").navigationBarTitleDisplayMode(.inline)
            .onChange(of: firstID) { _, _ in rate = min(rate, commonMaximum); invalidate() }
            .onChange(of: secondID) { _, _ in rate = min(rate, commonMaximum); invalidate() }
            .onChange(of: rate) { _, _ in invalidate() }
            .onChange(of: temperature) { _, _ in invalidate() }
    }
    private func presetPicker(title: String, id: Binding<String>) -> some View {
        HStack {
            Text(title).font(.system(.headline, design: .monospaced)).foregroundStyle(title == "A" ? LabStyle.cyan : LabStyle.violet)
            Picker("Specimen \(title)", selection: id) {
                ForEach(CellPreset.all) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    private func compute() {
        isComputing = true
        let selected = comparisonPresets
        let currentRevision = revision
        let cRate = rate
        let ambient = temperature
        Task {
            let calculated = await Task.detached(priority: .userInitiated) {
                var output: [String: ComparisonRun] = [:]
                for preset in selected {
                    var simulation = BatterySimulation(preset: preset, initialSOC: 1, ambientCelsius: ambient)
                    let input = SimulationInput(mode: .discharge, cRate: cRate, ambientCelsius: ambient)
                    var points: [ComparisonPoint] = []
                    var peak = ambient
                    let step = min(86400.0, 3600 / cRate / 240)
                    let sampleCount = min(600, Int(ceil(1.25 * 3600 / cRate / step)))
                    for index in 0...sampleCount {
                        let s = simulation.snapshot
                        points.append(ComparisonPoint(id: index, minutes: s.elapsedSeconds / 60, voltageFraction: s.voltage / preset.packNominalVoltage, charge: s.soc))
                        peak = max(peak, s.temperatureCelsius)
                        if s.phase == .depleted || s.phase == .temperatureHold { break }
                        _ = simulation.step(seconds: step, input: input)
                    }
                    output[preset.id] = ComparisonRun(points: points, energy: simulation.snapshot.energyDeliveredWh, peakTemperature: peak, endPhase: simulation.snapshot.phase.title)
                }
                return output
            }.value
            if revision == currentRevision { results = calculated }
            isComputing = false
        }
    }
    private func invalidate() { revision += 1; results = [:] }
}
