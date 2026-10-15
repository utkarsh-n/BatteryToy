import Foundation

/// A uniform-cell, one-RC terminal model. Positive current delivers energy to a load.
/// Charge control, nonlinear limits, thermal response and aging are educational approximations.
public struct BatterySimulation: Sendable {
    public let preset: CellPreset
    public private(set) var snapshot: BatterySnapshot

    private var soc: Double
    private var soh: Double = 1
    private var temperatureCelsius: Double
    private var ambientCelsius: Double
    private var polarization: Double = 0
    private var elapsedSeconds: Double = 0
    private var deliveredWh: Double = 0
    private var chargedWh: Double = 0
    private var resistiveLossWh: Double = 0
    private var chemicalWorkWh: Double = 0
    private var equivalentCycles: Double = 0
    private var chargeComplete = false
    private var dischargeCutoff = false
    private var chargePeakVoltage: Double = 0
    private var chargeSeconds: Double = 0
    private var lastMode: OperatingMode = .rest
    private var lastRate: Double = 0

    public init(preset: CellPreset, initialSOC: Double = 0.62, ambientCelsius: Double = 25) {
        self.preset = preset
        self.soc = bounded(initialSOC, 0, 1, fallback: 0.62)
        self.ambientCelsius = bounded(ambientCelsius, -40, 70, fallback: 25)
        self.temperatureCelsius = self.ambientCelsius
        self.snapshot = BatterySnapshot(soc: self.soc, soh: 1,
            temperatureCelsius: self.temperatureCelsius,
            voltage: preset.openCircuitVoltage(soc: self.soc) * Double(preset.series),
            currentAmps: 0, powerWatts: 0, heatWatts: 0, polarizationVoltage: 0,
            openCircuitVoltage: preset.openCircuitVoltage(soc: self.soc) * Double(preset.series),
            cRate: 0, elapsedSeconds: 0, energyDeliveredWh: 0, energyChargedWh: 0,
            equivalentCycles: 0, phase: .rest, warning: nil, estimatedRuntimeSeconds: nil,
            packCapacityAh: preset.packCapacityAh,
            effectiveResistanceOhms: preset.model.ohmicResistance * Double(preset.series) / Double(preset.parallel),
            resistiveLossWh: 0, chemicalWorkWh: 0, polarizationStoredEnergyWh: 0,
            seriesCount: preset.series)
    }

    public mutating func reset(initialSOC: Double = 0.62) {
        self = BatterySimulation(preset: preset, initialSOC: initialSOC, ambientCelsius: ambientCelsius)
    }

    /// Each call is bounded to one simulated day. Internal substeps bound SOC movement;
    /// the RC and constant-coefficient thermal updates are analytic within each substep.
    @discardableResult
    public mutating func step(seconds: Double, input: SimulationInput) -> BatterySnapshot {
        guard seconds.isFinite, seconds > 0 else { return snapshot }
        let duration = min(seconds, 86_400)
        let requestedRate = bounded(input.cRate, 0, 10, fallback: 0)
        ambientCelsius = bounded(input.ambientCelsius, -40, 70, fallback: ambientCelsius)
        let cooling = bounded(input.coolingMultiplier, 0.05, 10, fallback: 1)
        if input.mode != lastMode {
            dischargeCutoff = false
            if input.mode != .charge { chargeComplete = false; chargePeakVoltage = 0; chargeSeconds = 0 }
        }
        if abs(requestedRate - lastRate) > 1e-10 { dischargeCutoff = false }
        lastMode = input.mode; lastRate = requestedRate

        var remaining = duration
        while remaining > 1e-8 {
            let dt = min(remaining, max(0.25, min(60, 7.2 / max(0.001, requestedRate))))
            advance(seconds: dt, mode: input.mode, requestedRate: requestedRate,
                    cooling: cooling, agingEnabled: input.agingEnabled)
            remaining -= dt
        }
        return snapshot
    }

    private mutating func advance(seconds dt: Double, mode: OperatingMode,
                                  requestedRate: Double, cooling: Double, agingEnabled: Bool) {
        let m = preset.model
        let capacity = preset.capacityAh * soh
        let thermalFactor = bounded(exp(m.coldResistanceCoefficient * (25 - temperatureCelsius)), 0.65, 5, fallback: 1)
        let agingFactor = 1 + 2.5 * (1 - soh)
        let emptyFactor = 1 + 0.6 * pow(1 - soc, 4)
        let r0 = m.ohmicResistance * thermalFactor * agingFactor * emptyFactor
        let rp = m.polarizationResistance * thermalFactor * agingFactor
        let ocvBefore = preset.openCircuitVoltage(soc: soc)
        var phase: BatteryPhase = .rest
        var warning: String?
        var i: Double = 0
        var acceptanceResistance: Double = 0
        var isFloat = false

        if requestedRate > 0 {
            switch mode {
            case .rest: break
            case .discharge:
                let rate = min(requestedRate, m.maxDischargeCRate)
                let floorSOC = unavailableFraction(cRate: rate)
                if temperatureCelsius < preset.minDischargeCelsius || temperatureCelsius > preset.maxDischargeCelsius {
                    phase = .temperatureHold
                    warning = "Discharge held outside the preset's modeled temperature window."
                } else if dischargeCutoff || soc <= floorSOC + 1e-10 {
                    dischargeCutoff = true; phase = .depleted
                } else {
                    i = capacity * rate
                    let immediateVoltage = ocvBefore - i * r0 - polarization
                    if immediateVoltage <= m.cutoffVoltage {
                        i = 0; dischargeCutoff = true; phase = .depleted
                    } else {
                        // End exactly at the inventory floor rather than leaking charge below it.
                        i = min(i, max(0, (soc - floorSOC) * capacity * 3_600 / dt))
                        phase = .constantCurrentDischarge
                    }
                }
                if phase == .depleted { warning = "Load disconnected at the modeled cutoff; rest can restore voltage, not chemical charge." }
            case .charge:
                if !preset.isRechargeable {
                    phase = .chargeProhibited; warning = "Primary cell: charging is prohibited."
                } else if temperatureCelsius < preset.minChargeCelsius || temperatureCelsius > preset.maxChargeCelsius {
                    phase = .temperatureHold
                    warning = "Charge held outside the preset's modeled temperature window."
                } else if chargeComplete || soc >= 1 - 1e-10 {
                    chargeComplete = true
                    phase = preset.chemistry == .leadAcid ? .float : .chargeComplete
                    if preset.chemistry == .leadAcid {
                        isFloat = true
                        acceptanceResistance = r0 * 600
                        let target = bounded(m.floatVoltage - 0.003 * (temperatureCelsius - 25), 2.15, 2.4, fallback: m.floatVoltage)
                        let a = exp(-dt / m.relaxationSeconds)
                        let required = max(0, (target - ocvBefore + a * polarization)
                            / (r0 + acceptanceResistance + rp * (1 - a)))
                        i = -min(required, capacity * min(requestedRate, 0.005))
                    }
                } else if preset.chemistry == .nickelMetalHydride {
                    let rate = min(requestedRate, m.maxChargeCRate)
                    i = -min(capacity * rate, (1 - soc) * capacity * 3_600 / (dt * m.chargeEfficiency))
                    phase = .nickelCharge
                    chargeSeconds += dt
                } else {
                    let lowSOC = soc < 0.06 && preset.chemistry != .leadAcid && preset.chemistry != .vanadiumFlow
                    let rate = min(requestedRate, m.maxChargeCRate, lowSOC ? 0.1 : 10)
                    let maximum = min(capacity * rate, (1 - soc) * capacity * 3_600 / (dt * m.chargeEfficiency))
                    var chargeCurrent = maximum
                    let target = chargeCeiling()
                    let unconstrainedVoltage = predictedChargeVoltage(current: maximum, seconds: dt,
                                                                      r0: r0, rp: rp, capacity: capacity)
                    let voltageLimited = unconstrainedVoltage >= target
                    if voltageLimited {
                        var low = 0.0, high = maximum
                        for _ in 0..<45 {
                            let trial = (low + high) * 0.5
                            if predictedChargeVoltage(current: trial, seconds: dt, r0: r0, rp: rp, capacity: capacity) > target {
                                high = trial
                            } else { low = trial }
                        }
                        chargeCurrent = low
                    }
                    let terminationSOC = preset.chemistry == .leadAcid ? 0.995 : 0.95
                    if chargeCurrent <= 0.03 * capacity && soc >= terminationSOC {
                        chargeComplete = true
                        phase = preset.chemistry == .leadAcid ? .float : .chargeComplete
                    } else {
                        i = -chargeCurrent
                        let futureSOC = min(1, soc + chargeCurrent * dt * m.chargeEfficiency / (3_600 * capacity))
                        acceptanceResistance = leadAcceptanceResistance(soc: futureSOC, r0: r0)
                        if preset.chemistry == .leadAcid { phase = voltageLimited ? .absorption : .constantCurrentCharge }
                        else if preset.chemistry == .vanadiumFlow { phase = .flowCharge }
                        else { phase = lowSOC ? .precharge : (voltageLimited ? .constantVoltageCharge : .constantCurrentCharge) }
                    }
                }
            }
        }

        if warning == nil {
            let limit = mode == .charge ? m.maxChargeCRate : m.maxDischargeCRate
            if mode != .rest && requestedRate > limit && limit > 0 {
                warning = "Requested current is limited to this illustrative preset's operating envelope."
            }
        }

        if i > 0 {
            let predicted = predictedDischargeVoltage(current: i, seconds: dt, r0: r0, rp: rp, capacity: capacity)
            if predicted < m.cutoffVoltage - 1e-9 {
                var low = 0.0, high = dt
                for _ in 0..<45 {
                    let middle = (low + high) * 0.5
                    if predictedDischargeVoltage(current: i, seconds: middle, r0: r0, rp: rp, capacity: capacity) > m.cutoffVoltage {
                        low = middle
                    } else { high = middle }
                }
                if low > 1e-7 {
                    advance(seconds: low, mode: mode, requestedRate: requestedRate,
                            cooling: cooling, agingEnabled: agingEnabled)
                }
                dischargeCutoff = true
                let restDuration = dt - low
                if restDuration > 1e-7 {
                    advance(seconds: restDuration, mode: mode, requestedRate: requestedRate,
                            cooling: cooling, agingEnabled: agingEnabled)
                }
                return
            }
        }

        let a = exp(-dt / m.relaxationSeconds)
        let beforePolarization = polarization
        let asymptote = i * rp
        polarization = asymptote + (polarization - asymptote) * a
        let delta = beforePolarization - asymptote
        let averageP = asymptote + delta * m.relaxationSeconds / dt * (1 - a)
        let averageP2 = asymptote * asymptote
            + 2 * asymptote * delta * m.relaxationSeconds / dt * (1 - a)
            + delta * delta * m.relaxationSeconds / (2 * dt) * (1 - a * a)
        let oldSOC = soc
        let floatStorageFraction = isFloat && i < 0
            ? min(1, max(0, (1 - soc) * 3_600 * capacity / (abs(i) * dt * m.chargeEfficiency))) : 1
        let efficiency = i < 0 ? m.chargeEfficiency * floatStorageFraction : 1
        soc = bounded(soc - i * dt * efficiency / (3_600 * capacity), 0, 1, fallback: soc)
        let ocvAfter = preset.openCircuitVoltage(soc: soc)
        let count = Double(preset.series) * Double(preset.parallel)
        let resistorHeat = max(0, i * i * (r0 + acceptanceResistance) + averageP2 / rp)
        let additionalNickelHeat = preset.chemistry == .nickelMetalHydride && i < 0
            ? abs(i) * ocvAfter * 0.35 * max(0, (soc - 0.9) / 0.1) : 0
        let floatMaintenanceHeat = isFloat ? abs(i) * (ocvBefore + ocvAfter) * 0.5 * (1 - floatStorageFraction) : 0
        let heatPerCell = resistorHeat + additionalNickelHeat + floatMaintenanceHeat
        let thermalR = m.thermalResistanceKPerW / cooling
        let thermalA = exp(-dt / (m.thermalCapacityJPerK * thermalR))
        let previousTemperature = temperatureCelsius
        temperatureCelsius = ambientCelsius + (temperatureCelsius - ambientCelsius) * thermalA
            + heatPerCell * thermalR * (1 - thermalA)

        // Integrate the exact average RC voltage, rather than multiplying final power by dt.
        let electrodeWh = count * i * (ocvBefore + ocvAfter) * 0.5 * dt / 3_600
        let chemicalWh = electrodeWh * floatStorageFraction
        let terminalWh = electrodeWh - count * (i * i * (r0 + acceptanceResistance) + i * averageP) * dt / 3_600
        if terminalWh >= 0 { deliveredWh += terminalWh } else { chargedWh -= terminalWh }
        resistiveLossWh += count * (resistorHeat + floatMaintenanceHeat) * dt / 3_600
        chemicalWorkWh += chemicalWh
        equivalentCycles += abs(soc - oldSOC) * 0.5

        if agingEnabled && abs(i) > 0 {
            let stress = 1 + max(0, temperatureCelsius - 25) * 0.035 + max(0, abs(i) / capacity - 1) * 0.15
            soh = max(0.5, soh - abs(soc - oldSOC) * 0.5 * m.illustrativeFadePerCycle * stress)
        }

        let cellVoltage = max(0, ocvAfter - i * (r0 + acceptanceResistance) - polarization)
        if phase == .nickelCharge {
            chargePeakVoltage = max(chargePeakVoltage, cellVoltage)
            let deltaTPerMinute = (temperatureCelsius - previousTemperature) / dt * 60
            let peakDrop = chargePeakVoltage - cellVoltage
            let timerLimit = 1.6 / max(0.01, min(requestedRate, m.maxChargeCRate)) * 3_600
            if soc >= 1 - 1e-10 || (soc >= 0.96 && peakDrop >= 0.005)
                || (soc >= 0.95 && deltaTPerMinute >= 0.8) || chargeSeconds >= timerLimit {
                chargeComplete = true
                // The next substep disconnects the current; this snapshot accurately records this final current interval.
                warning = "NiMH termination detected from the modeled peak / thermal / timer signal."
            }
        }
        if phase == .constantCurrentDischarge && (cellVoltage <= m.cutoffVoltage || soc <= unavailableFraction(cRate: abs(i) / capacity) + 1e-10) {
            dischargeCutoff = true
        }
        elapsedSeconds += dt
        let packI = i * Double(preset.parallel)
        let packV = cellVoltage * Double(preset.series)
        let floorSOC = unavailableFraction(cRate: max(0, i / capacity))
        let runtime = i > 0 ? max(0, (soc - floorSOC) * capacity * 3_600 / i) : nil
        let storedRC = count * 0.5 * (m.relaxationSeconds / rp) * polarization * polarization / 3_600
        snapshot = BatterySnapshot(soc: soc, soh: soh, temperatureCelsius: temperatureCelsius,
            voltage: packV, currentAmps: packI, powerWatts: packV * packI,
            heatWatts: heatPerCell * count,
            polarizationVoltage: polarization * Double(preset.series),
            openCircuitVoltage: ocvAfter * Double(preset.series), cRate: i / capacity,
            elapsedSeconds: elapsedSeconds, energyDeliveredWh: deliveredWh,
            energyChargedWh: chargedWh, equivalentCycles: equivalentCycles,
            phase: phase, warning: warning, estimatedRuntimeSeconds: runtime,
            packCapacityAh: preset.packCapacityAh * soh,
            effectiveResistanceOhms: (r0 + acceptanceResistance) * Double(preset.series) / Double(preset.parallel),
            resistiveLossWh: resistiveLossWh, chemicalWorkWh: chemicalWorkWh,
            polarizationStoredEnergyWh: storedRC, seriesCount: preset.series)
    }

    private func unavailableFraction(cRate: Double) -> Double {
        let m = preset.model
        let coldAvailability = bounded(1 - max(0, 25 - temperatureCelsius) * m.coldAvailabilityCoefficient,
                                       0.45, 1, fallback: 1)
        let rateAvailability = cRate > m.ratedCRate
            ? bounded(pow(m.ratedCRate / cRate, m.rateCapacityExponent), 0.4, 1, fallback: 1) : 1
        return 1 - coldAvailability * rateAvailability
    }

    private func chargeCeiling() -> Double {
        if preset.chemistry == .leadAcid {
            // Representative -3 mV / °C / cell compensation, bounded for this teaching controller.
            return bounded(preset.model.chargeVoltage - 0.003 * (temperatureCelsius - 25), 2.3, 2.5, fallback: 2.4)
        }
        return preset.model.chargeVoltage
    }

    private func leadAcceptanceResistance(soc: Double, r0: Double) -> Double {
        guard preset.chemistry == .leadAcid else { return 0 }
        // Phenomenological charge acceptance, absent during discharge and rest.
        return r0 * 500 * pow(max(0, (soc - 0.75) / 0.25), 3)
    }

    private func predictedChargeVoltage(current: Double, seconds: Double,
                                        r0: Double, rp: Double, capacity: Double) -> Double {
        let predictedSOC = min(1, soc + current * seconds * preset.model.chargeEfficiency / (3_600 * capacity))
        let a = exp(-seconds / preset.model.relaxationSeconds)
        let predictedP = -current * rp + (polarization + current * rp) * a
        let acceptance = leadAcceptanceResistance(soc: predictedSOC, r0: r0)
        return preset.openCircuitVoltage(soc: predictedSOC) + current * (r0 + acceptance) - predictedP
    }

    private func predictedDischargeVoltage(current: Double, seconds: Double,
                                           r0: Double, rp: Double, capacity: Double) -> Double {
        let predictedSOC = max(0, soc - current * seconds / (3_600 * capacity))
        let a = exp(-seconds / preset.model.relaxationSeconds)
        let predictedP = current * rp + (polarization - current * rp) * a
        return preset.openCircuitVoltage(soc: predictedSOC) - current * r0 - predictedP
    }
}

private func bounded(_ value: Double, _ lower: Double, _ upper: Double, fallback: Double) -> Double {
    value.isFinite ? min(upper, max(lower, value)) : fallback
}
