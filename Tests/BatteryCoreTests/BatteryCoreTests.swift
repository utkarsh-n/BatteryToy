import XCTest
@testable import BatteryCore

final class BatteryCoreTests: XCTestCase {
    func testCatalogCoversTwelveScalesAndSourceAttribution() {
        XCTAssertEqual(CellPreset.all.count, 12)
        XCTAssertEqual(Set(CellPreset.all.map(\.id)).count, 12)
        XCTAssertLessThan(CellPreset.nanoSolidState.nominalEnergyWh, 1e-8)
        XCTAssertEqual(CellPreset.vanadiumFlow.nominalEnergyWh, 1_000_000, accuracy: 1e-6)
        for preset in CellPreset.all {
            XCTAssertFalse(preset.sources.isEmpty, preset.id)
            XCTAssertTrue(preset.sources.allSatisfy { $0.url.hasPrefix("https://") }, preset.id)
            XCTAssertGreaterThan(preset.capacityAh, 0, preset.id)
            XCTAssertTrue(preset.modelScope.contains("not a calibrated"), preset.id)
        }
    }

    func testCoulombCountingMatchesAnalyticHalfCRate() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.8)
        let result = sim.step(seconds: 360, input: .init(mode: .discharge, cRate: 0.5))
        XCTAssertEqual(result.soc, 0.75, accuracy: 1e-12)
        XCTAssertEqual(result.currentAmps, 2, accuracy: 1e-12)
        XCTAssertEqual(result.elapsedSeconds, 360, accuracy: 1e-10)
    }

    func testChargeEfficiencyAppearsInCoulombBalance() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.5)
        let result = sim.step(seconds: 360, input: .init(mode: .charge, cRate: 0.2))
        XCTAssertEqual(result.soc, 0.5 + 0.02 * CellPreset.phoneNMC.model.chargeEfficiency, accuracy: 1e-12)
        XCTAssertLessThan(result.currentAmps, 0)
        XCTAssertLessThan(result.powerWatts, 0)
        XCTAssertGreaterThan(result.voltage, result.openCircuitVoltage)
    }

    func testRestRelaxationIsExactAndDoesNotRecoverSOC() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.6)
        let loaded = sim.step(seconds: 120, input: .init(mode: .discharge, cRate: 0.5))
        let rested = sim.step(seconds: 210, input: .init(mode: .rest))
        let expectedP = loaded.polarizationVoltage * exp(-210 / CellPreset.phoneNMC.model.relaxationSeconds)
        XCTAssertEqual(rested.polarizationVoltage, expectedP, accuracy: 1e-12)
        XCTAssertEqual(rested.soc, loaded.soc, accuracy: 1e-12)
        XCTAssertEqual(rested.currentAmps, 0)
        XCTAssertGreaterThan(rested.voltage, loaded.voltage)
        XCTAssertEqual(rested.energyDeliveredWh, loaded.energyDeliveredWh, accuracy: 1e-12)
    }

    func testElectricalWorkBalancesTerminalLossAndStoredRC() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.8)
        let loaded = sim.step(seconds: 100, input: .init(mode: .discharge, cRate: 0.4))
        XCTAssertEqual(loaded.chemicalWorkWh,
                       loaded.energyDeliveredWh + loaded.resistiveLossWh + loaded.polarizationStoredEnergyWh,
                       accuracy: 5e-5)
        let rested = sim.step(seconds: 700, input: .init(mode: .rest))
        XCTAssertEqual(rested.chemicalWorkWh,
                       rested.energyDeliveredWh + rested.resistiveLossWh + rested.polarizationStoredEnergyWh,
                       accuracy: 5e-5)
    }

    func testSeriesParallelVoltageCurrentEnergyAndHeatScaling() {
        let base = CellPreset.phoneNMC
        var one = BatterySimulation(preset: base, initialSOC: 0.7)
        var pack = BatterySimulation(preset: base.withPack(series: 4, parallel: 3), initialSOC: 0.7)
        let input = SimulationInput(mode: .discharge, cRate: 0.5)
        let a = one.step(seconds: 300, input: input)
        let b = pack.step(seconds: 300, input: input)
        XCTAssertEqual(a.soc, b.soc, accuracy: 1e-12)
        XCTAssertEqual(b.voltage, a.voltage * 4, accuracy: 1e-9)
        XCTAssertEqual(b.currentAmps, a.currentAmps * 3, accuracy: 1e-9)
        XCTAssertEqual(b.energyDeliveredWh, a.energyDeliveredWh * 12, accuracy: 1e-9)
        XCTAssertEqual(b.heatWatts, a.heatWatts * 12, accuracy: 1e-9)
        XCTAssertEqual(b.temperatureCelsius, a.temperatureCelsius, accuracy: 1e-9)
        XCTAssertEqual(b.packCapacityAh, a.packCapacityAh * 3, accuracy: 1e-9)
        XCTAssertEqual(b.effectiveResistanceOhms, a.effectiveResistanceOhms * 4 / 3, accuracy: 1e-9)
    }

    func testPrimaryChemistriesRejectEveryChargingRequest() {
        for preset in [CellPreset.alkalineAA, .lithiumCoin] {
            var sim = BatterySimulation(preset: preset, initialSOC: 0.4)
            let result = sim.step(seconds: 10_000, input: .init(mode: .charge, cRate: 2))
            XCTAssertEqual(result.phase, .chargeProhibited, preset.id)
            XCTAssertEqual(result.currentAmps, 0, preset.id)
            XCTAssertEqual(result.soc, 0.4, accuracy: 1e-12, preset.id)
            XCTAssertEqual(result.energyChargedWh, 0, preset.id)
        }
    }

    func testDischargeCutoffDisconnectsAndPreservesRemainingCharge() {
        var sim = BatterySimulation(preset: .alkalineAA, initialSOC: 0.6)
        let cut = sim.step(seconds: 30_000, input: .init(mode: .discharge, cRate: 0.5))
        XCTAssertEqual(cut.phase, .depleted)
        XCTAssertEqual(cut.currentAmps, 0)
        XCTAssertGreaterThan(cut.soc, 0)
        let continued = sim.step(seconds: 600, input: .init(mode: .discharge, cRate: 0.5))
        XCTAssertEqual(continued.soc, cut.soc, accuracy: 1e-12)
        let rested = sim.step(seconds: 1_000, input: .init(mode: .rest))
        XCTAssertEqual(rested.soc, cut.soc, accuracy: 1e-12)
    }

    func testLithiumPassesPrechargeConstantCurrentCVAndTermination() {
        var pre = BatterySimulation(preset: .phoneNMC, initialSOC: 0.02)
        let precharge = pre.step(seconds: 1, input: .init(mode: .charge, cRate: 1))
        XCTAssertEqual(precharge.phase, .precharge)
        XCTAssertEqual(abs(precharge.cRate), 0.1, accuracy: 1e-12)
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.3)
        var sawCC = false, sawCV = false
        for _ in 0..<300 {
            let x = sim.step(seconds: 60, input: .init(mode: .charge, cRate: 0.8))
            sawCC = sawCC || x.phase == .constantCurrentCharge
            sawCV = sawCV || x.phase == .constantVoltageCharge
            XCTAssertLessThanOrEqual(x.voltage, 4.2 + 1e-7)
            if x.phase == .chargeComplete { break }
        }
        XCTAssertTrue(sawCC)
        XCTAssertTrue(sawCV)
        XCTAssertEqual(sim.snapshot.phase, .chargeComplete)
        XCTAssertEqual(sim.snapshot.currentAmps, 0)
        XCTAssertGreaterThan(sim.snapshot.soc, 0.95)
    }

    func testLeadAcidReachesAbsorptionAndFloat() {
        var sim = BatterySimulation(preset: .leadAcid, initialSOC: 0.5)
        var sawAbsorption = false
        for _ in 0..<2_000 {
            let x = sim.step(seconds: 60, input: .init(mode: .charge, cRate: 0.25))
            sawAbsorption = sawAbsorption || x.phase == .absorption
            if x.phase == .float { break }
        }
        XCTAssertTrue(sawAbsorption)
        XCTAssertEqual(sim.snapshot.phase, .float)
        let maintained = sim.step(seconds: 60, input: .init(mode: .charge, cRate: 0.25))
        let target = (CellPreset.leadAcid.model.floatVoltage - 0.003 * (maintained.temperatureCelsius - 25)) * 6
        XCTAssertEqual(maintained.voltage, target, accuracy: 0.003)
        XCTAssertLessThan(maintained.currentAmps, 0)
        XCTAssertLessThanOrEqual(abs(maintained.currentAmps), 0.005 * CellPreset.leadAcid.packCapacityAh)
        XCTAssertGreaterThan(sim.snapshot.soc, 0.95)
    }

    func testLeadDefaultDischargeRunsForTenMinutes() {
        var sim = BatterySimulation(preset: .leadAcid, initialSOC: 0.62)
        let x = sim.step(seconds: 600, input: .init(mode: .discharge, cRate: 0.5))
        XCTAssertEqual(x.phase, .constantCurrentDischarge)
        XCTAssertEqual(x.currentAmps, 30, accuracy: 1e-9)
        XCTAssertEqual(x.soc, 0.62 - 0.5 / 6, accuracy: 1e-10)
        XCTAssertGreaterThan(x.voltage, CellPreset.leadAcid.model.cutoffVoltage * 6)
    }

    func testSaturatedFloatInputBecomesHeatRatherThanChemicalEnergy() {
        var sim = BatterySimulation(preset: .leadAcid, initialSOC: 1)
        let x = sim.step(seconds: 1_000, input: .init(mode: .charge, cRate: 0.25))
        XCTAssertEqual(x.phase, .float)
        XCTAssertEqual(x.soc, 1)
        XCTAssertEqual(x.chemicalWorkWh, 0, accuracy: 1e-12)
        XCTAssertLessThan(x.currentAmps, 0)
        XCTAssertGreaterThan(x.heatWatts, 0)
        XCTAssertEqual(x.energyChargedWh, x.resistiveLossWh + x.polarizationStoredEnergyWh, accuracy: 1e-5)
    }

    func testAcceleratedChargeAgreesWithFineStepsAcrossPhases() {
        var coarse = BatterySimulation(preset: .phoneNMC, initialSOC: 0.2)
        var fine = coarse
        let input = SimulationInput(mode: .charge, cRate: 1)
        coarse.step(seconds: 3_600, input: input)
        for _ in 0..<3_600 { fine.step(seconds: 1, input: input) }
        XCTAssertEqual(coarse.snapshot.soc, fine.snapshot.soc, accuracy: 0.003)
        XCTAssertEqual(coarse.snapshot.voltage, fine.snapshot.voltage, accuracy: 0.01)
        XCTAssertEqual(coarse.snapshot.energyChargedWh, fine.snapshot.energyChargedWh, accuracy: 0.06)
    }

    func testNiMHUsesNickelPhaseAndTerminatesWithoutCV() {
        var sim = BatterySimulation(preset: .nimhAA, initialSOC: 0.5)
        var sawNickel = false
        for _ in 0..<300 {
            let x = sim.step(seconds: 60, input: .init(mode: .charge, cRate: 0.5))
            sawNickel = sawNickel || x.phase == .nickelCharge
            XCTAssertNotEqual(x.phase, .constantVoltageCharge)
            if x.phase == .chargeComplete { break }
        }
        XCTAssertTrue(sawNickel)
        XCTAssertEqual(sim.snapshot.phase, .chargeComplete)
        XCTAssertEqual(sim.snapshot.currentAmps, 0)
    }

    func testTemperatureHoldAndReversibleCoolingDoNotCreateCharge() {
        var cold = BatterySimulation(preset: .phoneNMC, initialSOC: 0.6, ambientCelsius: -10)
        let blocked = cold.step(seconds: 100, input: .init(mode: .charge, cRate: 1, ambientCelsius: -10))
        XCTAssertEqual(blocked.phase, .temperatureHold)
        XCTAssertEqual(blocked.currentAmps, 0)
        XCTAssertEqual(blocked.soc, 0.6, accuracy: 1e-12)
        let warmed = cold.step(seconds: 10_000, input: .init(mode: .rest, ambientCelsius: 25))
        XCTAssertEqual(warmed.soc, 0.6, accuracy: 1e-12)
        XCTAssertGreaterThan(warmed.temperatureCelsius, blocked.temperatureCelsius)
        XCTAssertLessThanOrEqual(warmed.temperatureCelsius, 25)
    }

    func testHeatRisesUnderLoadThenCoolsAtRest() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.9)
        let hot = sim.step(seconds: 600, input: .init(mode: .discharge, cRate: 1))
        XCTAssertGreaterThan(hot.heatWatts, 0)
        XCTAssertGreaterThan(hot.temperatureCelsius, 25)
        let cool = sim.step(seconds: 2_000, input: .init(mode: .rest))
        XCTAssertLessThan(cool.temperatureCelsius, hot.temperatureCelsius)
        XCTAssertGreaterThanOrEqual(cool.temperatureCelsius, 25)
    }

    func testAgingIsOptInAndClearlyBounded() {
        var disabled = BatterySimulation(preset: .phoneNMC, initialSOC: 0.9)
        var enabled = BatterySimulation(preset: .phoneNMC, initialSOC: 0.9)
        let a = disabled.step(seconds: 1_000, input: .init(mode: .discharge, cRate: 0.5))
        let b = enabled.step(seconds: 1_000, input: .init(mode: .discharge, cRate: 0.5, agingEnabled: true))
        XCTAssertEqual(a.soh, 1)
        XCTAssertLessThan(b.soh, 1)
        XCTAssertGreaterThanOrEqual(b.soh, 0.5)
        XCTAssertEqual(a.equivalentCycles, (0.9 - a.soc) / 2, accuracy: 1e-12)
    }

    func testResetRestoresFreshInitialSnapshot() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: 0.8)
        sim.step(seconds: 1_000, input: .init(mode: .discharge, cRate: 0.8))
        sim.reset(initialSOC: 0.4)
        XCTAssertEqual(sim.snapshot.soc, 0.4)
        XCTAssertEqual(sim.snapshot.phase, .rest)
        XCTAssertEqual(sim.snapshot.elapsedSeconds, 0)
        XCTAssertEqual(sim.snapshot.energyDeliveredWh, 0)
        XCTAssertEqual(sim.snapshot.polarizationVoltage, 0)
        XCTAssertEqual(sim.snapshot.soh, 1)
    }

    func testInvalidInputsRemainFiniteAndTimeBounded() {
        var sim = BatterySimulation(preset: .phoneNMC, initialSOC: .nan, ambientCelsius: .infinity)
        let initial = sim.snapshot
        XCTAssertEqual(sim.step(seconds: .nan, input: .init()).elapsedSeconds, initial.elapsedSeconds)
        XCTAssertEqual(sim.step(seconds: -1, input: .init()).soc, initial.soc)
        let a = sim.step(seconds: 100, input: .init(mode: .discharge, cRate: .infinity,
                                                   ambientCelsius: .nan, coolingMultiplier: .nan))
        XCTAssertTrue(a.voltage.isFinite)
        XCTAssertTrue(a.temperatureCelsius.isFinite)
        XCTAssertEqual(a.currentAmps, 0)
        XCTAssertEqual(a.soc, initial.soc, accuracy: 1e-12)
    }

    func testEveryPresetCompletesMixedModeStressWithoutNonfiniteState() {
        for preset in CellPreset.all {
            var sim = BatterySimulation(preset: preset, initialSOC: 0.7)
            for mode in [OperatingMode.discharge, .rest, .charge, .rest] {
                let x = sim.step(seconds: 5_000, input: .init(mode: mode, cRate: 0.3))
                XCTAssertTrue(x.voltage.isFinite && x.powerWatts.isFinite && x.heatWatts.isFinite, preset.id)
                XCTAssertTrue((0...1).contains(x.soc), preset.id)
                XCTAssertTrue(x.temperatureCelsius.isFinite, preset.id)
                XCTAssertGreaterThanOrEqual(x.energyDeliveredWh, 0, preset.id)
                XCTAssertGreaterThanOrEqual(x.energyChargedWh, 0, preset.id)
            }
        }
    }
}
