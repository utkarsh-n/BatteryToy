import SwiftUI
import Charts
import BatteryCore

struct BatteryBench: View {
    @Bindable var lab: BatteryLab
    var motion: MotionLight
    var showSheet: (LabSheet) -> Void
    @State private var signal = TraceSignal.voltage
    private var accent: Color { LabStyle.accent(lab.preset) }
    var body: some View {
        LabScroll {
            specimenHeader
            HologramView(charge: lab.snapshot.soc, current: lab.snapshot.currentAmps,
                         temperature: lab.snapshot.temperatureCelsius, form: lab.preset.formFactor.rawValue,
                         accent: accent, phase: lab.snapshot.phase.title, motion: motion,
                         isRunning: lab.running, exploded: lab.exploded, selectedLayer: $lab.selectedLayer,
                         carrierDirection: carrierDirection, carrierLabel: lab.preset.chemistry.ionSymbol)
                .frame(height: 310)
            heroActions
            if let selected = lab.selectedLayer {
                LayerExplanation(preset: lab.preset, layer: selected, mode: lab.mode)
            }
            meters
            phaseReadout
            experimentControls
            tracePanel
            chemistryPanel
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LabStyle.background, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: lab.mode)
        .sensoryFeedback(.selection, trigger: lab.preset.id)
        .sensoryFeedback(.impact(weight: .light), trigger: lab.exploded)
        .sensoryFeedback(.selection, trigger: lab.snapshot.phase)
    }
    private var specimenHeader: some View {
        HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(lab.preset.scaleName.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(1.6).foregroundStyle(accent)
                    Text(lab.preset.name).font(.system(.title, design: .rounded, weight: .medium)).foregroundStyle(LabStyle.ink)
                    Text(lab.preset.chemistry.title).font(.subheadline).foregroundStyle(LabStyle.muted)
                }
                Spacer(minLength: 2)
                Button { showSheet(.specimens) } label: {
                    Image(systemName: "chevron.up.chevron.down").font(.subheadline).frame(width: 24, height: 24)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.large).tint(accent)
                .accessibilityLabel("Choose battery. Current: \(lab.preset.name)").accessibilityIdentifier("choose-battery")
        }.padding(.top, 6)
    }
    private var heroActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button { lab.exploded.toggle() } label: { Label(lab.exploded ? "Assemble" : "See inside", systemImage: "square.3.layers.3d") }
                    .buttonStyle(GlassControlStyle(tint: accent)).accessibilityIdentifier("see-inside")
                Button { showSheet(.physics) } label: { Label("How it works", systemImage: "sparkle.magnifyingglass") }
                    .buttonStyle(GlassControlStyle(tint: accent))
                Spacer(minLength: 0)
            }
        }
    }
    private var phaseReadout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(lab.running ? accent : LabStyle.muted).frame(width: 6, height: 6)
                Text(lab.snapshot.phase.title.uppercased()).font(.system(.caption, design: .monospaced, weight: .semibold)).tracking(1.2).foregroundStyle(accent)
                Spacer()
                Text("T+ \(durationText(lab.snapshot.elapsedSeconds))").font(.system(.caption, design: .monospaced)).foregroundStyle(LabStyle.muted).monospacedDigit()
            }
            Text(lab.snapshot.phase.detail).font(.subheadline).foregroundStyle(LabStyle.muted).fixedSize(horizontal: false, vertical: true)
            if let warning = lab.snapshot.warning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(LabStyle.amber).fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("phase-readout")
    }
    private var meters: some View {
        LabPanel(title: "Live terminals", icon: "waveform.path") {
            HStack(spacing: 12) {
                Readout(title: "Voltage", value: quantity(lab.snapshot.voltage, "V"), tint: accent)
                Readout(title: "Current", value: quantity(lab.snapshot.currentAmps, "A"), tint: accent)
                Readout(title: "Power", value: quantity(lab.snapshot.powerWatts, "W"), tint: accent)
            }
            Divider().overlay(.white.opacity(0.04))
            HStack(spacing: 12) {
                Readout(title: "Cell temp", value: String(format: "%.1f °C", lab.snapshot.temperatureCelsius), tint: LabStyle.amber)
                Readout(title: "Heat", value: quantity(lab.snapshot.heatWatts, "W"), tint: LabStyle.amber)
                Readout(title: "Delivered", value: quantity(lab.snapshot.energyDeliveredWh, "Wh"), tint: LabStyle.violet)
            }
            Text("+ current leaves the cell · − current charges it").font(.caption2).foregroundStyle(LabStyle.muted)
        }
    }
    private var experimentControls: some View {
        LabPanel(title: "Experiment", icon: "slider.horizontal.3") {
            Picker("Operating mode", selection: Binding(get: { lab.mode }, set: { lab.setMode($0) })) {
                Text("Discharge").tag(OperatingMode.discharge)
                Text("Rest").tag(OperatingMode.rest)
                Text("Charge").tag(OperatingMode.charge)
            }.pickerStyle(.segmented).accessibilityIdentifier("operating-mode")
            ValueSlider(title: lab.mode == .charge ? "Charge rate" : "Load", value: Binding(get: { log10(lab.cRate) }, set: { lab.cRate = pow(10, $0) }), range: -4...log10(3),
                        formatted: String(format: "%.3g C", lab.cRate),
                        footnote: "Requested: \(quantity(lab.cRate * lab.preset.packCapacityAh, "A")) · 1 C is an ideal one-hour discharge", tint: accent)
            ValueSlider(title: "Ambient temperature", value: $lab.ambient, range: -20...55,
                        formatted: String(format: "%.0f °C", lab.ambient), tint: LabStyle.amber)
            ValueSlider(title: "Cooling", value: $lab.cooling, range: 0.1...5,
                        formatted: String(format: "%.1f ×", lab.cooling), footnote: "Changes heat exchange with the surroundings", tint: LabStyle.violet)
            HStack {
                Text("Time scale").font(.subheadline)
                Spacer()
                Picker("Time scale", selection: $lab.speed) {
                    Text("Real time").tag(1.0)
                    Text("30 ×").tag(30.0)
                    Text("120 ×").tag(120.0)
                    Text("600 ×").tag(600.0)
                }.pickerStyle(.menu).tint(accent)
            }
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        lab.running.toggle()
                    } label: {
                        Label(lab.running ? "Pause" : "Run", systemImage: lab.running ? "pause.fill" : "play.fill").frame(minWidth: 55)
                    }.buttonStyle(.glassProminent).controlSize(.large).tint(accent).accessibilityIdentifier("run-simulation")
                    Button { lab.jump(minutes: 10) } label: { Label("10 min", systemImage: "forward.end") }
                        .buttonStyle(GlassControlStyle(tint: accent)).accessibilityIdentifier("advance-time")
                    Button { lab.running = false; lab.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                        .buttonStyle(GlassControlStyle(tint: accent)).accessibilityLabel("Reset simulation")
                }
            }
            DisclosureGroup("Set initial charge") {
                ValueSlider(title: "Charge", value: Binding(get: { lab.snapshot.soc }, set: { lab.scrub(to: $0) }), range: 0...1,
                            formatted: String(format: "%.0f %%", lab.snapshot.soc * 100),
                            footnote: "Starts a fresh experiment at this charge", tint: accent).padding(.top, 10)
                HStack {
                    Button("Empty") { lab.scrub(to: 0.02) }
                    Spacer()
                    Button("Half") { lab.scrub(to: 0.5) }
                    Spacer()
                    Button("Full") { lab.scrub(to: 1) }
                }.buttonStyle(.bordered).padding(.top, 5)
            }.font(.subheadline).tint(accent)
            DisclosureGroup("Build a balanced pack") {
                VStack(alignment: .leading, spacing: 12) {
                    Stepper("Series · \(lab.preset.series) cells", value: Binding(get: { lab.preset.series }, set: { lab.configurePack(series: $0, parallel: lab.preset.parallel) }), in: 1...1000)
                    Stepper("Parallel · \(lab.preset.parallel) strings", value: Binding(get: { lab.preset.parallel }, set: { lab.configurePack(series: lab.preset.series, parallel: $0) }), in: 1...1000)
                    HStack {
                        Readout(title: "Voltage", value: quantity(lab.preset.packNominalVoltage, "V"), tint: accent)
                        Readout(title: "Capacity", value: quantity(lab.preset.packCapacityAh, "Ah"), tint: accent)
                    }
                    Text(lab.preset.chemistry == .vanadiumFlow ? "Series scales the stack; parallel scales a complete stack-and-tank unit together. Independent tank sizing is outside this model." : "Series adds voltage. Parallel adds ampere-hours. This model assumes identical, balanced cells and cooling per cell.")
                        .font(.caption).foregroundStyle(LabStyle.muted)
                }.padding(.top, 12)
            }.font(.subheadline).tint(accent)
            DisclosureGroup("Cycle aging demonstration") {
                Toggle("Illustrative capacity fade", isOn: $lab.illustrativeAging).padding(.top, 10)
                Text("State of health: \(String(format: "%.2f", lab.snapshot.soh * 100))% · \(String(format: "%.2f", lab.snapshot.equivalentCycles)) equivalent cycles")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(accent)
                Text("A teaching rule based on throughput and temperature. These coefficients are not measured lifetime predictions.")
                    .font(.caption).foregroundStyle(LabStyle.muted)
            }.font(.subheadline).tint(accent)
        }
    }
    private var carrierDirection: Double {
        switch lab.preset.chemistry {
        case .alkaline, .nickelMetalHydride: -1
        case .leadAcid: 0
        default: 1
        }
    }
    private var tracePanel: some View {
        LabPanel(title: "Live trace", icon: "chart.xyaxis.line") {
            Picker("Trace signal", selection: $signal) { ForEach(TraceSignal.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Chart(lab.history) { point in
                LineMark(x: .value("Time (minutes)", point.time / 60), y: .value(signal.title, signal.value(point)))
                    .foregroundStyle(accent).interpolationMethod(.linear)
            }
            .chartXAxisLabel("Simulated minutes")
            .chartYAxisLabel(signal.unit)
            .chartYScale(domain: traceDomain)
            .frame(height: 140)
            .accessibilityIdentifier("live-trace")
            .accessibilityLabel("\(signal.title) over time. Current value \(signal.formatted(lab.snapshot))")
            if lab.history.count < 2 { Text("Run or advance time to draw the trace.").font(.caption).foregroundStyle(LabStyle.muted) }
            if !lab.phaseChanges.isEmpty {
                ForEach(lab.phaseChanges.prefix(3), id: \.self) { Text($0).font(.system(.caption2, design: .monospaced)).foregroundStyle(LabStyle.muted) }
            }
        }
    }
    private var traceDomain: ClosedRange<Double> {
        let values = lab.history.map { signal.value($0) }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, abs(maxValue) * 0.05, 0.01)
        return (minValue - span * 0.1)...(maxValue + span * 0.1)
    }
    private var chemistryPanel: some View {
        LabPanel(title: "Why this battery", icon: "atom") {
            Text(lab.preset.subtitle).font(.headline).foregroundStyle(LabStyle.ink)
            Text(lab.preset.mechanism).font(.subheadline).foregroundStyle(LabStyle.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Readout(title: "Nominal energy", value: quantity(lab.preset.nominalEnergyWh, "Wh"), tint: accent)
                Readout(title: "Configuration", value: "\(lab.preset.series)s · \(lab.preset.parallel)p", tint: accent)
            }
            Text("Representative reduced-order model · tap How it works for equations, chemistry, and limits.").font(.caption).foregroundStyle(LabStyle.muted)
        }
    }
}

enum TraceSignal: String, CaseIterable, Identifiable {
    case voltage, current, temperature, charge
    var id: String { rawValue }
    var title: String { switch self { case .voltage: "Voltage"; case .current: "Current"; case .temperature: "Temp"; case .charge: "Charge" } }
    var unit: String { switch self { case .voltage: "V"; case .current: "A"; case .temperature: "°C"; case .charge: "%" } }
    func value(_ p: TracePoint) -> Double { switch self { case .voltage: p.voltage; case .current: p.current; case .temperature: p.temperature; case .charge: p.soc * 100 } }
    func formatted(_ s: BatterySnapshot) -> String { switch self { case .voltage: quantity(s.voltage,"V"); case .current: quantity(s.currentAmps,"A"); case .temperature: String(format:"%.1f °C",s.temperatureCelsius); case .charge: String(format:"%.0f %%",s.soc*100) } }
}

struct LayerExplanation: View {
    var preset: CellPreset
    var layer: Int
    var mode: OperatingMode
    private var title: String { layer == 0 ? "Negative electrode" : layer == 1 ? "Electrolyte & separator" : "Positive electrode" }
    private var detail: String {
        layer == 0 ? preset.chemistry.anode : layer == 1 ? preset.chemistry.electrolyte : preset.chemistry.cathode
    }
    var body: some View {
        LabPanel(title: title, icon: layer == 1 ? "arrow.left.arrow.right" : "circle.hexagongrid") {
            Text(detail).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text(layer == 1 ? "Ions move through this region. Electrons take the external circuit." : "Electrode names refer to discharge: the negative side is the anode and the positive side is the cathode. The reaction reverses during charging.")
                .font(.caption).foregroundStyle(LabStyle.muted)
        }
    }
}
