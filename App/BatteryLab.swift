import Foundation
import Observation
import BatteryCore

struct TracePoint: Identifiable {
    let id: Int
    let time: Double
    let voltage: Double
    let current: Double
    let temperature: Double
    let soc: Double
}

@Observable @MainActor
final class BatteryLab {
    var preset: CellPreset
    var simulation: BatterySimulation
    var snapshot: BatterySnapshot
    var mode: OperatingMode = .discharge
    var cRate: Double = 0.5
    var ambient: Double = 25
    var cooling: Double = 1
    var illustrativeAging = false
    var speed: Double = 120
    var running = false
    var exploded = false
    var selectedLayer: Int?
    var history: [TracePoint] = []
    var phaseChanges: [String] = []
    private var sampleID = 0
    private var lastSampleTime: Double = -10
    init() {
        let stored = ProcessInfo.processInfo.arguments.contains("--ui-testing") ? nil : UserDefaults.standard.string(forKey: "BatteryToy.preset")
        let chosen = CellPreset.all.first { $0.id == stored } ?? CellPreset.all.first { $0.formFactor.rawValue == "pouch" } ?? CellPreset.all[0]
        preset = chosen
        let initial = BatterySimulation(preset: chosen)
        simulation = initial
        snapshot = initial.snapshot
        cRate = chosen.chemistry == .lithiumPrimary ? 0.001 : min(0.5, chosen.model.maxDischargeCRate)
        record()
    }
    var input: SimulationInput {
        SimulationInput(mode: mode, cRate: cRate, ambientCelsius: ambient, coolingMultiplier: cooling, agingEnabled: illustrativeAging)
    }
    func select(_ next: CellPreset) {
        preset = next
        UserDefaults.standard.set(next.id, forKey: "BatteryToy.preset")
        simulation = BatterySimulation(preset: next, ambientCelsius: ambient)
        snapshot = simulation.snapshot
        mode = .discharge
        cRate = next.chemistry == .lithiumPrimary ? 0.001 : min(0.5, next.model.maxDischargeCRate)
        running = false
        selectedLayer = nil
        clearHistory()
    }
    func reset(soc: Double = 0.62) {
        simulation = BatterySimulation(preset: preset, initialSOC: soc, ambientCelsius: ambient)
        snapshot = simulation.snapshot
        clearHistory()
    }
    func configurePack(series: Int, parallel: Int) {
        running = false
        preset = preset.withPack(series: series, parallel: parallel)
        reset()
    }
    func scrub(to soc: Double) {
        running = false
        reset(soc: soc)
    }
    func setMode(_ newMode: OperatingMode) {
        mode = newMode
        advance(seconds: 0.01)
    }
    func tick(realSeconds: Double) {
        guard running else { return }
        advance(seconds: min(realSeconds, 0.25) * speed)
    }
    func jump(minutes: Double) { advance(seconds: minutes * 60) }
    func advance(seconds: Double) {
        let previous = snapshot.phase
        snapshot = simulation.step(seconds: seconds, input: input)
        if snapshot.phase != previous {
            phaseChanges.insert("\(durationText(snapshot.elapsedSeconds)) · \(snapshot.phase.title)", at: 0)
            phaseChanges = Array(phaseChanges.prefix(8))
        }
        record()
    }
    private func clearHistory() {
        history = []; phaseChanges = []; sampleID = 0; lastSampleTime = -10; record()
    }
    private func record() {
        guard snapshot.elapsedSeconds - lastSampleTime >= 1 || history.isEmpty else { return }
        history.append(TracePoint(id: sampleID, time: snapshot.elapsedSeconds, voltage: snapshot.voltage, current: snapshot.currentAmps,
                                  temperature: snapshot.temperatureCelsius, soc: snapshot.soc))
        sampleID += 1
        lastSampleTime = snapshot.elapsedSeconds
        if history.count > 600 { history.removeFirst(history.count - 600) }
    }
}
