import Foundation

public enum BatteryFormFactor: String, CaseIterable, Sendable {
    case nano, thinFilm, cylinder, coin, prismatic, pouch, pack, flow
}

public enum BatteryAccent: String, CaseIterable, Sendable {
    case cyan, violet, amber, lime, coral, mint, blue, indigo
}

public enum BatteryChemistry: String, CaseIterable, Sendable {
    case solidState, alkaline, lithiumPrimary, nickelMetalHydride, leadAcid
    case lithiumIonNMC, lithiumIronPhosphate, sodiumIon, lithiumSulfur, vanadiumFlow

    public var title: String {
        switch self {
        case .solidState: "Solid-state lithium"
        case .alkaline: "Alkaline · Zn / MnO₂"
        case .lithiumPrimary: "Primary lithium · Li / MnO₂"
        case .nickelMetalHydride: "Nickel–metal hydride"
        case .leadAcid: "Lead–acid"
        case .lithiumIonNMC: "Lithium-ion · NMC"
        case .lithiumIronPhosphate: "Lithium iron phosphate"
        case .sodiumIon: "Sodium-ion"
        case .lithiumSulfur: "Lithium–sulfur"
        case .vanadiumFlow: "Vanadium redox flow"
        }
    }

    public var chargeProtocol: String {
        switch self {
        case .alkaline, .lithiumPrimary: "Primary cell · charging prohibited"
        case .nickelMetalHydride: "Constant current · −ΔV / thermal / time termination"
        case .leadAcid: "Bulk → absorption → float"
        case .vanadiumFlow: "Controlled current · stack voltage ceiling · SOC cutoff"
        case .lithiumSulfur: "Research-specific current / voltage control"
        case .solidState: "Device-specific current / voltage limits"
        case .lithiumIonNMC, .lithiumIronPhosphate, .sodiumIon: "Precharge → constant current → constant voltage → stop"
        }
    }

    /// A charge carrier label, not a claim that every ion moves in one direction.
    public var ionSymbol: String {
        switch self {
        case .alkaline, .nickelMetalHydride: "OH⁻"
        case .leadAcid: "H⁺ / SO₄²⁻"
        case .sodiumIon: "Na⁺"
        case .vanadiumFlow: "H⁺"
        default: "Li⁺"
        }
    }

    public var anode: String {
        switch self {
        case .solidState: "Lithium-storage electrode · architecture dependent"
        case .alkaline: "Zinc"
        case .lithiumPrimary, .lithiumSulfur: "Lithium metal"
        case .nickelMetalHydride: "Hydrogen-storage metal alloy"
        case .leadAcid: "Lead · Pb"
        case .lithiumIonNMC, .lithiumIronPhosphate: "Graphite"
        case .sodiumIon: "Hard carbon"
        case .vanadiumFlow: "Negative electrolyte · V²⁺ / V³⁺"
        }
    }

    public var cathode: String {
        switch self {
        case .solidState: "Lithium-host oxide · illustrative"
        case .alkaline, .lithiumPrimary: "Manganese dioxide · MnO₂"
        case .nickelMetalHydride: "Nickel oxyhydroxide · NiOOH"
        case .leadAcid: "Lead dioxide · PbO₂"
        case .lithiumIonNMC: "Nickel–manganese–cobalt oxide"
        case .lithiumIronPhosphate: "LiFePO₄ / FePO₄"
        case .sodiumIon: "Prussian-white sodium host · example"
        case .lithiumSulfur: "Sulfur ↔ lithium sulfides"
        case .vanadiumFlow: "Positive electrolyte · V⁴⁺ / V⁵⁺"
        }
    }

    public var electrolyte: String {
        switch self {
        case .solidState: "Solid lithium-ion conductor"
        case .alkaline, .nickelMetalHydride: "Aqueous potassium hydroxide"
        case .leadAcid: "Aqueous sulfuric acid"
        case .vanadiumFlow: "Vanadium species in acid · pumped through a stack"
        case .lithiumSulfur: "Lithium salt in an ether-based liquid · example"
        case .sodiumIon: "Sodium salt in organic electrolyte · example"
        default: "Lithium salt in organic electrolyte"
        }
    }
}

public enum OperatingMode: String, CaseIterable, Sendable {
    case rest, discharge, charge
    public var title: String { rawValue.capitalized }
}

public enum BatteryPhase: String, CaseIterable, Sendable {
    case rest, constantCurrentDischarge, depleted, precharge, constantCurrentCharge
    case constantVoltageCharge, absorption, float, nickelCharge, flowCharge
    case chargeComplete, chargeProhibited, temperatureHold

    public var title: String {
        switch self {
        case .rest: "Rest · relaxation"
        case .constantCurrentDischarge: "Constant-current discharge"
        case .depleted: "Discharge cutoff"
        case .precharge: "Precharge"
        case .constantCurrentCharge: "Constant-current charge"
        case .constantVoltageCharge: "Constant-voltage taper"
        case .absorption: "Absorption"
        case .float: "Float maintenance"
        case .nickelCharge: "NiMH constant-current charge"
        case .flowCharge: "Flow-stack charge"
        case .chargeComplete: "Charge complete"
        case .chargeProhibited: "Primary · charge blocked"
        case .temperatureHold: "Temperature hold"
        }
    }

    public var detail: String {
        switch self {
        case .rest: "Current is zero. Polarization relaxes and terminal voltage approaches open-circuit voltage; chemical SOC does not recover."
        case .constantCurrentDischarge: "The load requests a fixed current. Resistance and polarization lower the terminal voltage."
        case .depleted: "The modeled voltage or accessible-capacity cutoff disconnects the load. Some chemical charge may remain."
        case .precharge: "Low-SOC cells receive a reduced current before the normal charge stage. Device-specific limits apply."
        case .constantCurrentCharge: "The charger supplies its selected current until the modeled voltage ceiling is reached."
        case .constantVoltageCharge: "The voltage ceiling limits current. Current tapers as the cell approaches full charge."
        case .absorption: "The lead-acid charger holds its absorption ceiling while modeled charge acceptance falls."
        case .float: "The lead-acid controller uses a lower, temperature-compensated maintenance ceiling. A small modeled current tops up charge; near full, maintenance energy becomes heat."
        case .nickelCharge: "NiMH uses current control and peak-voltage, temperature, and timer termination; it does not use lithium-style CV taper."
        case .flowCharge: "Current charges the tank inventory through the stack, subject to a stack voltage ceiling and inventory cutoff."
        case .chargeComplete: "The modeled charger has terminated and current is zero."
        case .chargeProhibited: "This primary chemistry is not rechargeable. The model admits no charging current."
        case .temperatureHold: "The modeled controller stops current outside this preset's operating window."
        }
    }
}

public struct BatterySource: Hashable, Sendable {
    public let title: String
    public let url: String
    public init(_ title: String, _ url: String) { self.title = title; self.url = url }
}

public struct SimulationInput: Sendable {
    public var mode: OperatingMode
    public var cRate: Double
    public var ambientCelsius: Double
    public var coolingMultiplier: Double
    public var agingEnabled: Bool
    public init(mode: OperatingMode = .discharge, cRate: Double = 0.5,
                ambientCelsius: Double = 25, coolingMultiplier: Double = 1,
                agingEnabled: Bool = false) {
        self.mode = mode; self.cRate = cRate; self.ambientCelsius = ambientCelsius
        self.coolingMultiplier = coolingMultiplier; self.agingEnabled = agingEnabled
    }
}

public struct BatterySnapshot: Sendable {
    public let soc: Double
    public let soh: Double
    public let temperatureCelsius: Double
    public let voltage: Double
    public let currentAmps: Double
    public let powerWatts: Double
    public let heatWatts: Double
    public let polarizationVoltage: Double
    public let openCircuitVoltage: Double
    public let cRate: Double
    public let elapsedSeconds: Double
    public let energyDeliveredWh: Double
    public let energyChargedWh: Double
    public let equivalentCycles: Double
    public let phase: BatteryPhase
    public let warning: String?
    public let estimatedRuntimeSeconds: Double?
    public let packCapacityAh: Double
    public let effectiveResistanceOhms: Double
    public let resistiveLossWh: Double
    public let chemicalWorkWh: Double
    public let polarizationStoredEnergyWh: Double
    public var stateOfCharge: Double { soc }
    public var temperature: Double { temperatureCelsius }
    public var voltagePerCell: Double { voltage / Double(max(1, seriesCount)) }
    public let seriesCount: Int
}

public struct VoltagePoint: Sendable {
    public let soc: Double
    public let volts: Double
    public init(_ soc: Double, _ volts: Double) { self.soc = soc; self.volts = volts }
}

/// Independently chosen teaching parameters. These are not fitted manufacturer curves.
public struct CellModelParameters: Sendable {
    public let ocvCurve: [VoltagePoint]
    public let ohmicResistance: Double
    public let polarizationResistance: Double
    public let relaxationSeconds: Double
    public let thermalCapacityJPerK: Double
    public let thermalResistanceKPerW: Double
    public let cutoffVoltage: Double
    public let chargeVoltage: Double
    public let floatVoltage: Double
    public let maxChargeCRate: Double
    public let maxDischargeCRate: Double
    public let chargeEfficiency: Double
    public let coldResistanceCoefficient: Double
    public let coldAvailabilityCoefficient: Double
    public let rateCapacityExponent: Double
    public let ratedCRate: Double
    public let illustrativeFadePerCycle: Double

    public init(ocvCurve: [VoltagePoint], ohmicResistance: Double,
                polarizationResistance: Double, relaxationSeconds: Double,
                thermalCapacityJPerK: Double, thermalResistanceKPerW: Double,
                cutoffVoltage: Double, chargeVoltage: Double, floatVoltage: Double = 0,
                maxChargeCRate: Double, maxDischargeCRate: Double,
                chargeEfficiency: Double = 0.99, coldResistanceCoefficient: Double = 0.025,
                coldAvailabilityCoefficient: Double = 0.006,
                rateCapacityExponent: Double = 0, ratedCRate: Double = 0.05,
                illustrativeFadePerCycle: Double = 0.0002) {
        self.ocvCurve = ocvCurve; self.ohmicResistance = max(1e-12, ohmicResistance)
        self.polarizationResistance = max(1e-12, polarizationResistance)
        self.relaxationSeconds = max(1e-6, relaxationSeconds)
        self.thermalCapacityJPerK = max(1e-12, thermalCapacityJPerK)
        self.thermalResistanceKPerW = max(1e-12, thermalResistanceKPerW)
        self.cutoffVoltage = cutoffVoltage; self.chargeVoltage = chargeVoltage
        self.floatVoltage = floatVoltage; self.maxChargeCRate = max(0, maxChargeCRate)
        self.maxDischargeCRate = max(0, maxDischargeCRate)
        self.chargeEfficiency = min(1, max(0.1, chargeEfficiency))
        self.coldResistanceCoefficient = max(0, coldResistanceCoefficient)
        self.coldAvailabilityCoefficient = max(0, coldAvailabilityCoefficient)
        self.rateCapacityExponent = max(0, rateCapacityExponent)
        self.ratedCRate = max(0.0001, ratedCRate)
        self.illustrativeFadePerCycle = max(0, illustrativeFadePerCycle)
    }
}

public struct CellPreset: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let chemistry: BatteryChemistry
    public let subtitle: String
    public let scaleName: String
    public let formFactor: BatteryFormFactor
    public let capacityAh: Double
    public let nominalVoltage: Double
    public let series: Int
    public let parallel: Int
    public let accent: BatteryAccent
    public let useCases: [String]
    public let strengths: [String]
    public let tradeoffs: [String]
    public let mechanism: String
    public let sources: [BatterySource]
    public let model: CellModelParameters
    public let isRechargeable: Bool
    public let minChargeCelsius: Double
    public let maxChargeCelsius: Double
    public let minDischargeCelsius: Double
    public let maxDischargeCelsius: Double
    public let maturity: String
    public var summary: String { subtitle }
    public var packCapacityAh: Double { capacityAh * Double(parallel) }
    public var packNominalVoltage: Double { nominalVoltage * Double(series) }
    public var nominalEnergyWh: Double { packCapacityAh * packNominalVoltage }
    public var tint: BatteryAccent { accent }
    public var modelScope: String {
        "Educational terminal-response model. OCV, resistance, heat, aging and cutoff parameters are illustrative, not a calibrated device prediction."
    }

    public init(id: String, name: String, chemistry: BatteryChemistry, subtitle: String,
                scaleName: String, formFactor: BatteryFormFactor, capacityAh: Double,
                nominalVoltage: Double, series: Int = 1, parallel: Int = 1,
                accent: BatteryAccent, useCases: [String], strengths: [String],
                tradeoffs: [String], mechanism: String, sources: [BatterySource],
                model: CellModelParameters, isRechargeable: Bool = true,
                minChargeCelsius: Double = 0, maxChargeCelsius: Double = 45,
                minDischargeCelsius: Double = -20, maxDischargeCelsius: Double = 60,
                maturity: String = "Established chemistry · illustrative device") {
        self.id = id; self.name = name; self.chemistry = chemistry; self.subtitle = subtitle
        self.scaleName = scaleName; self.formFactor = formFactor
        self.capacityAh = max(1e-15, capacityAh); self.nominalVoltage = nominalVoltage
        self.series = max(1, series); self.parallel = max(1, parallel); self.accent = accent
        self.useCases = useCases; self.strengths = strengths; self.tradeoffs = tradeoffs
        self.mechanism = mechanism; self.sources = sources; self.model = model
        self.isRechargeable = isRechargeable; self.minChargeCelsius = minChargeCelsius
        self.maxChargeCelsius = maxChargeCelsius; self.minDischargeCelsius = minDischargeCelsius
        self.maxDischargeCelsius = maxDischargeCelsius; self.maturity = maturity
    }

    public func withPack(series: Int, parallel: Int) -> CellPreset {
        CellPreset(id: id, name: name, chemistry: chemistry, subtitle: subtitle,
                   scaleName: scaleName, formFactor: formFactor, capacityAh: capacityAh,
                   nominalVoltage: nominalVoltage, series: series, parallel: parallel,
                   accent: accent, useCases: useCases, strengths: strengths, tradeoffs: tradeoffs,
                   mechanism: mechanism, sources: sources, model: model, isRechargeable: isRechargeable,
                   minChargeCelsius: minChargeCelsius, maxChargeCelsius: maxChargeCelsius,
                   minDischargeCelsius: minDischargeCelsius, maxDischargeCelsius: maxDischargeCelsius,
                   maturity: maturity)
    }

    public func openCircuitVoltage(soc: Double) -> Double {
        let x = soc.isFinite ? min(1, max(0, soc)) : 0.5
        let curve = model.ocvCurve
        guard let first = curve.first, let last = curve.last else { return nominalVoltage }
        if x <= first.soc { return first.volts }
        if x >= last.soc { return last.volts }
        for index in 1..<curve.count where x <= curve[index].soc {
            let a = curve[index - 1], b = curve[index]
            let t = (x - a.soc) / max(1e-12, b.soc - a.soc)
            return a.volts + t * (b.volts - a.volts)
        }
        return last.volts
    }
}
