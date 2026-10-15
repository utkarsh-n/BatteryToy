import Foundation

public extension CellPreset {
    static let all: [CellPreset] = [nanoSolidState, thinFilm, alkalineAA, lithiumCoin, nimhAA,
                                    leadAcid, phoneNMC, lfpPrismatic, lfpEV, sodiumIon,
                                    lithiumSulfur, vanadiumFlow]

    static let nanoSolidState = CellPreset(
        id: "nano-solid-state", name: "Nano solid-state", chemistry: .solidState,
        subtitle: "A conceptual nanocell · short transport distances, tiny inventory",
        scaleName: "Nanoscale concept", formFactor: .nano, capacityAh: 1e-9,
        nominalVoltage: 3.2, accent: .violet,
        useCases: ["Research into conformal electrolytes", "Microsystems · conceptual"],
        strengths: ["Short ion paths", "Can conform to three-dimensional structures"],
        tradeoffs: ["An individual cell stores almost no energy", "Interfaces and fabrication dominate"],
        mechanism: "Lithium moves through a solid ion conductor while electrons take the external circuit. Nanoscale ALD research has demonstrated LiCoO₂ cathodes, silicon anodes and very thin LiPON-family electrolytes. This nanocell's absolute capacity and voltage curve are conceptual; they are not measurements from that paper.",
        sources: [.init("Pearse et al. · nanoscale solid-state batteries", "https://arxiv.org/abs/1702.04009")],
        model: .init(ocvCurve: curve([2.3, 2.9, 3.2, 3.35, 3.65, 4.0]),
                     ohmicResistance: 2e7, polarizationResistance: 1e7, relaxationSeconds: 0.2,
                     thermalCapacityJPerK: 1e-8, thermalResistanceKPerW: 3e7,
                     cutoffVoltage: 2.4, chargeVoltage: 4.0, maxChargeCRate: 0.5,
                     maxDischargeCRate: 2, illustrativeFadePerCycle: 0.0005),
        maturity: "Research-inspired concept · all numerical parameters illustrative")

    static let thinFilm = CellPreset(
        id: "thin-film", name: "Thin-film microbattery", chemistry: .solidState,
        subtitle: "Deposited active layers · a solid electrolyte replaces liquid",
        scaleName: "Microsystem", formFactor: .thinFilm, capacityAh: 50e-6,
        nominalVoltage: 3.8, accent: .cyan,
        useCases: ["Sensor backup", "Energy-harvesting microsystems"],
        strengths: ["Thin deposited architecture", "Small solid-electrolyte energy store"],
        tradeoffs: ["Limited absolute energy", "Manufacturing and solid interfaces matter"],
        mechanism: "A lithium-host cathode and a lithium-metal electrode exchange Li⁺ through solid LiPON. The electrolyte carries ions and separates the electron path. Thin-film cells demonstrate this architecture; interfaces can still create failure paths, so solid-state does not mean failure-proof.",
        sources: [.init("ORNL · LiPON thin-film research", "https://www.ornl.gov/research-highlight/deposition-and-confinement-li-metal-along-artificial-lipon-lipon-interface")],
        model: .init(ocvCurve: curve([2.8, 3.45, 3.7, 3.85, 4.02, 4.2]),
                     ohmicResistance: 1_500, polarizationResistance: 500, relaxationSeconds: 8,
                     thermalCapacityJPerK: 0.008, thermalResistanceKPerW: 800,
                     cutoffVoltage: 2.8, chargeVoltage: 4.2, maxChargeCRate: 0.5,
                     maxDischargeCRate: 2))

    static let alkalineAA = CellPreset(
        id: "alkaline-aa", name: "Alkaline AA", chemistry: .alkaline,
        subtitle: "Everyday primary power · voltage slopes as reactants are consumed",
        scaleName: "Handheld", formFactor: .cylinder, capacityAh: 2.5,
        nominalVoltage: 1.5, accent: .amber,
        useCases: ["Remote controls", "Clocks", "Occasional-use devices"],
        strengths: ["Convenient primary cell", "Good service at light drain"],
        tradeoffs: ["No recharging", "High drain reduces usable capacity"],
        mechanism: "Zinc oxidizes and manganese dioxide is reduced in an alkaline electrolyte. Hydroxide participates in the electrode reactions; this is not a lithium shuttle. Reactants change irreversibly in this primary cell. The rated capacity depends strongly on drain current and cutoff voltage.",
        sources: [.init("Energizer E91 · AA datasheet", "https://data.energizer.com/pdfs/e91.pdf"),
                  .init("Energizer · alkaline handbook", "https://data.energizer.com/pdfs/alkaline_appman.pdf")],
        model: .init(ocvCurve: curve([0.8, 1.0, 1.18, 1.32, 1.47, 1.6]),
                     ohmicResistance: 0.2, polarizationResistance: 0.12, relaxationSeconds: 150,
                     thermalCapacityJPerK: 25, thermalResistanceKPerW: 20,
                     cutoffVoltage: 0.8, chargeVoltage: 0, maxChargeCRate: 0,
                     maxDischargeCRate: 0.5, rateCapacityExponent: 0.15),
        isRechargeable: false, minDischargeCelsius: -18, maxDischargeCelsius: 55)

    static let lithiumCoin = CellPreset(
        id: "lithium-coin", name: "Lithium coin cell", chemistry: .lithiumPrimary,
        subtitle: "Li / MnO₂ primary · compact, long-lived, low-drain power",
        scaleName: "Coin cell", formFactor: .coin, capacityAh: 0.225,
        nominalVoltage: 3, accent: .coral,
        useCases: ["Memory backup", "Wireless tags", "Key fobs"],
        strengths: ["Compact 3 V primary cell", "Useful for tiny average loads"],
        tradeoffs: ["No recharging", "Continuous high current causes large sag"],
        mechanism: "Lithium metal oxidizes at the negative electrode. Li⁺ crosses the organic electrolyte and participates in reduction of MnO₂ at the positive electrode. A CR2032 is a primary cell; it must not be confused with a rechargeable lithium coin chemistry. Panasonic rates 225 mAh at a 0.2 mA standard drain.",
        sources: [.init("Panasonic · CR2032 specifications", "https://energy.panasonic.com/na/business/products/lithium/coin-cr-standard/models/CR2032")],
        model: .init(ocvCurve: curve([2.0, 2.65, 2.85, 2.98, 3.08, 3.2]),
                     ohmicResistance: 12, polarizationResistance: 8, relaxationSeconds: 90,
                     thermalCapacityJPerK: 2.5, thermalResistanceKPerW: 65,
                     cutoffVoltage: 2, chargeVoltage: 0, maxChargeCRate: 0,
                     maxDischargeCRate: 0.05, rateCapacityExponent: 0.08, ratedCRate: 0.001),
        isRechargeable: false, minDischargeCelsius: -30, maxDischargeCelsius: 60)

    static let nimhAA = CellPreset(
        id: "nimh-aa", name: "NiMH AA", chemistry: .nickelMetalHydride,
        subtitle: "Hydrogen stored in an alloy · reusable high-drain AA power",
        scaleName: "Handheld", formFactor: .cylinder, capacityAh: 2,
        nominalVoltage: 1.2, accent: .lime,
        useCases: ["Frequently used toys", "Camera flashes", "AA-powered instruments"],
        strengths: ["Rechargeable AA format", "Relatively low resistance"],
        tradeoffs: ["Lower nominal voltage than alkaline", "Needs nickel-specific charge termination"],
        mechanism: "The metal-hydride alloy releases stored hydrogen during discharge. At the positive electrode, NiOOH becomes Ni(OH)₂; hydroxide and water participate in both half-reactions. Recharge reverses those reactions. End-of-charge voltage and heating provide termination signals rather than a lithium-style CV stage.",
        sources: [.init("Energizer · NiMH handbook", "https://data.energizer.com/pdfs/nickelmetalhydride_appman.pdf"),
                  .init("TI · NiMH temperature termination", "https://www.ti.com/product/BQ2002T"),
                  .init("TI · peak-voltage / thermal termination", "https://e2e.ti.com/support/power-management-group/power-management/f/power-management-forum/74822/bq2002---charging-and-termination")],
        model: .init(ocvCurve: [.init(0, 0.95), .init(0.08, 1.17), .init(0.3, 1.24),
                              .init(0.7, 1.29), .init(0.9, 1.35), .init(0.98, 1.46), .init(1, 1.44)],
                     ohmicResistance: 0.03, polarizationResistance: 0.015, relaxationSeconds: 50,
                     thermalCapacityJPerK: 30, thermalResistanceKPerW: 18,
                     cutoffVoltage: 1, chargeVoltage: 1.6, maxChargeCRate: 0.5,
                     maxDischargeCRate: 3, chargeEfficiency: 0.88,
                     illustrativeFadePerCycle: 0.00035), maxChargeCelsius: 45)

    static let leadAcid = CellPreset(
        id: "lead-acid", name: "Lead–acid 12 V", chemistry: .leadAcid,
        subtitle: "Six cells · acid concentration changes with charge",
        scaleName: "Vehicle / backup", formFactor: .prismatic, capacityAh: 60,
        nominalVoltage: 2, series: 6, accent: .blue,
        useCases: ["Engine starting", "Backup power", "Cost-sensitive stationary storage"],
        strengths: ["Established and recyclable", "High pulse-current capability"],
        tradeoffs: ["Heavy", "High discharge rates reduce accessible capacity", "Deep discharge can shorten life"],
        mechanism: "Lead and lead dioxide both become lead sulfate on discharge, consuming sulfuric acid and producing water. Charging restores the electrodes and acid. A controlled charger uses bulk current, an absorption voltage ceiling, then a lower float voltage for standby maintenance.",
        sources: [.init("GS Yuasa · lead-acid charging instructions", "https://www.gs-yuasa.com/en/ps-eubr/pdf/Instructions_and_safety_information_for_Industrial_lead-acid_batteries.pdf"),
                  .init("GS Yuasa · traction-battery technical guide", "https://www.gs-yuasa.com/jp/products/traction_batteries/pdf/V_en.pdf")],
        model: .init(ocvCurve: curve([1.85, 1.97, 2.03, 2.08, 2.12, 2.15]),
                     ohmicResistance: 0.0008, polarizationResistance: 0.0006, relaxationSeconds: 180,
                     thermalCapacityJPerK: 1_500, thermalResistanceKPerW: 0.6,
                     cutoffVoltage: 1.75, chargeVoltage: 2.4, floatVoltage: 2.275,
                     maxChargeCRate: 0.25, maxDischargeCRate: 3, chargeEfficiency: 0.9,
                     rateCapacityExponent: 0.12, illustrativeFadePerCycle: 0.0006),
        maxChargeCelsius: 40, maxDischargeCelsius: 50)

    static let phoneNMC = CellPreset(
        id: "phone-nmc", name: "NMC phone pouch", chemistry: .lithiumIonNMC,
        subtitle: "A representative 4 Ah pouch · energy for a pocket computer",
        scaleName: "Personal electronics", formFactor: .pouch, capacityAh: 4,
        nominalVoltage: 3.7, accent: .cyan,
        useCases: ["Portable electronics", "Energy-dense rechargeable packs"],
        strengths: ["High energy in limited space", "Useful balance of energy and power"],
        tradeoffs: ["Charging temperature and voltage need control", "High SOC and heat can accelerate aging"],
        mechanism: "During discharge, lithium leaves graphite, crosses the electrolyte as Li⁺, and enters the NMC cathode. Electrons travel through the external load. Charging reverses this intercalation. This 4.2 V teaching example is not a model of any specific phone; commercial phones may use other cathodes and charge ceilings.",
        sources: [.init("DOE · NMC / graphite electrode materials", "https://www.energy.gov/congressional/articles/senate-energy-and-natural-resources-committee-september-17-2019"),
                  .init("TI BQ25629 · CC/CV control phases", "https://www.ti.com/product/BQ25629"),
                  .init("NMC calendar-loss research", "https://arxiv.org/abs/2103.02166")],
        model: .init(ocvCurve: curve([2.5, 3.25, 3.6, 3.78, 4.03, 4.2]),
                     ohmicResistance: 0.045, polarizationResistance: 0.025, relaxationSeconds: 70,
                     thermalCapacityJPerK: 75, thermalResistanceKPerW: 9,
                     cutoffVoltage: 2.8, chargeVoltage: 4.2, maxChargeCRate: 1,
                     maxDischargeCRate: 3))

    static let lfpPrismatic = CellPreset(
        id: "lfp-prismatic", name: "LFP storage cell", chemistry: .lithiumIronPhosphate,
        subtitle: "A broad, flat plateau · sturdy stationary energy storage",
        scaleName: "Large cell", formFactor: .prismatic, capacityAh: 100,
        nominalVoltage: 3.2, accent: .mint,
        useCases: ["Home storage", "Utility modules", "Frequent cycling"],
        strengths: ["Iron / phosphate cathode", "Broad voltage plateau"],
        tradeoffs: ["Voltage alone is a poor mid-range SOC gauge", "Lower energy density than many nickel-rich cells"],
        mechanism: "Lithium moves between graphite and an iron-phosphate cathode. Much of the cathode's reaction involves LiFePO₄ / FePO₄ phase coexistence, giving a broad plateau. The plotted OCV curve only illustrates that behavior; it does not resolve moving phase boundaries, particle stress or hysteresis.",
        sources: [.init("LFP phase-transition research", "https://arxiv.org/abs/1808.06164"),
                  .init("TI BQ25629 · LiFePO₄ charge support", "https://www.ti.com/product/BQ25629")],
        model: .init(ocvCurve: [.init(0, 2.0), .init(0.05, 3.08), .init(0.15, 3.22),
                              .init(0.8, 3.32), .init(0.95, 3.4), .init(1, 3.65)],
                     ohmicResistance: 0.0007, polarizationResistance: 0.0005, relaxationSeconds: 100,
                     thermalCapacityJPerK: 1_900, thermalResistanceKPerW: 0.8,
                     cutoffVoltage: 2.5, chargeVoltage: 3.65, maxChargeCRate: 0.5,
                     maxDischargeCRate: 2, illustrativeFadePerCycle: 0.00008))

    static let lfpEV = CellPreset(
        id: "lfp-ev", name: "LFP EV pack", chemistry: .lithiumIronPhosphate,
        subtitle: "128 × 150 Ah cells · a conceptual 61.4 kWh vehicle pack",
        scaleName: "Vehicle pack", formFactor: .pack, capacityAh: 150,
        nominalVoltage: 3.2, series: 128, accent: .mint,
        useCases: ["Electric vehicles", "Vehicle-to-grid concepts"],
        strengths: ["Series cells raise pack voltage", "Large energy store from many cells"],
        tradeoffs: ["Cells need balancing and thermal management", "Pack wiring and cooling add complexity"],
        mechanism: "The cell reaction is the same as the LFP storage example. Series cells add voltage; parallel strings add Ah. This ideal pack keeps every cell identical. Real packs include cell imbalance, busbars, contactors, a BMS and cooling paths that this model does not resolve.",
        sources: lfpPrismatic.sources,
        model: .init(ocvCurve: lfpPrismatic.model.ocvCurve,
                     ohmicResistance: 0.0005, polarizationResistance: 0.00035, relaxationSeconds: 100,
                     thermalCapacityJPerK: 2_600, thermalResistanceKPerW: 0.45,
                     cutoffVoltage: 2.5, chargeVoltage: 3.65, maxChargeCRate: 1,
                     maxDischargeCRate: 3, illustrativeFadePerCycle: 0.00008))

    static let sodiumIon = CellPreset(
        id: "sodium-ion", name: "Sodium-ion cell", chemistry: .sodiumIon,
        subtitle: "Hard carbon / Prussian-white example · an alternative ion shuttle",
        scaleName: "Storage / mobility", formFactor: .prismatic, capacityAh: 50,
        nominalVoltage: 3, accent: .indigo,
        useCases: ["Stationary storage", "Mobility applications selected for sodium chemistry"],
        strengths: ["Uses sodium-based active materials", "Some designs retain strong cold performance"],
        tradeoffs: ["Many chemistries and performance envelopes", "This example is not hot sodium–sulfur"],
        mechanism: "Na⁺ moves between a hard-carbon negative electrode and a sodium-host positive electrode. CATL's first-generation example used a Prussian-white cathode. Sodium-ion families differ; the sample charge ceiling and cold response here are illustrative rather than specifications for that product.",
        sources: [.init("CATL · first-generation sodium-ion architecture", "https://www.catl.com/en/news/665.html"),
                  .init("DOE · sodium-battery technology assessment", "https://www.energy.gov/sites/default/files/2023-07/Technology%20Strategy%20Assessment%20-%20Sodium%20Batteries.pdf")],
        model: .init(ocvCurve: curve([1.6, 2.5, 2.9, 3.1, 3.45, 3.8]),
                     ohmicResistance: 0.0015, polarizationResistance: 0.001, relaxationSeconds: 80,
                     thermalCapacityJPerK: 1_000, thermalResistanceKPerW: 1.1,
                     cutoffVoltage: 2, chargeVoltage: 3.8, maxChargeCRate: 0.5,
                     maxDischargeCRate: 2, coldResistanceCoefficient: 0.015,
                     coldAvailabilityCoefficient: 0.0018))

    static let lithiumSulfur = CellPreset(
        id: "lithium-sulfur", name: "Lithium–sulfur research", chemistry: .lithiumSulfur,
        subtitle: "Conversion chemistry · two discharge regions, new challenges",
        scaleName: "Research pouch", formFactor: .pouch, capacityAh: 3,
        nominalVoltage: 2.1, accent: .amber,
        useCases: ["Research into lightweight storage", "Experimental long-endurance power"],
        strengths: ["Sulfur stores charge by conversion reactions", "Potential for low active-material mass"],
        tradeoffs: ["Polysulfide shuttle can cause losses", "Lithium-metal interfaces and cycle life matter"],
        mechanism: "Sulfur converts through soluble polysulfides and toward lithium sulfide during discharge. The upper and lower voltage regions represent different conversion reactions, not charger phases. A polysulfide shuttle can cause self-discharge and poor cycling; this model illustrates the voltage regions without simulating that transport.",
        sources: [.init("ORNL · Li–S shuttle research", "https://www.ornl.gov/research-highlight/high-energy-lithium-sulfur-batteries"),
                  .init("ORNL · two-stage sulfur conversion research", "https://impact.ornl.gov/en/publications/fast-reversible-lithium-storage-with-a-sulfurlong-chain-polysulfi/")],
        model: .init(ocvCurve: [.init(0, 1.6), .init(0.08, 1.98), .init(0.6, 2.08),
                              .init(0.7, 2.28), .init(0.95, 2.38), .init(1, 2.6)],
                     ohmicResistance: 0.06, polarizationResistance: 0.04, relaxationSeconds: 120,
                     thermalCapacityJPerK: 55, thermalResistanceKPerW: 10,
                     cutoffVoltage: 1.8, chargeVoltage: 2.6, maxChargeCRate: 0.3,
                     maxDischargeCRate: 1, chargeEfficiency: 0.95,
                     illustrativeFadePerCycle: 0.001),
        maturity: "Research chemistry · illustrative device and protocol")

    static let vanadiumFlow = CellPreset(
        id: "vanadium-flow", name: "Vanadium flow plant", chemistry: .vanadiumFlow,
        subtitle: "Tank inventory sets energy · stack design sets power",
        scaleName: "Utility · conceptual 1 MWh", formFactor: .flow, capacityAh: 5_000,
        nominalVoltage: 1.25, series: 40, parallel: 4, accent: .coral,
        useCases: ["Long-duration grid storage", "Renewable generation shifting"],
        strengths: ["Energy and power can be sized separately", "Active material held in external tanks"],
        tradeoffs: ["Pumps and large tanks", "Stack, membrane and electrolyte losses"],
        mechanism: "Pumps move vanadium electrolytes from separate tanks through the stack. During discharge V²⁺ becomes V³⁺ on the negative side, while V⁵⁺ becomes V⁴⁺ on the positive side. Charge-balancing ions cross the membrane; the active fluids are intended to remain in their own half-circuits. More tank inventory increases energy, while stack area and current density govern power.",
        sources: [.init("DOE · flow-battery technology assessment", "https://www.energy.gov/sites/default/files/2023-07/Technology%20Strategy%20Assessment%20-%20Flow%20Batteries.pdf"),
                  .init("DOE · vanadium electrolyte / membrane schematic", "https://www.energy.gov/oe/articles/potential-benefits-high-power-high-capacity-batteries-january-2020")],
        model: .init(ocvCurve: curve([1.0, 1.13, 1.22, 1.3, 1.4, 1.55]),
                     ohmicResistance: 0.00015, polarizationResistance: 0.00008,
                     relaxationSeconds: 15, thermalCapacityJPerK: 1_000_000,
                     thermalResistanceKPerW: 0.001, cutoffVoltage: 0.8, chargeVoltage: 1.6,
                     maxChargeCRate: 0.15, maxDischargeCRate: 0.15,
                     chargeEfficiency: 0.98, illustrativeFadePerCycle: 0.00002),
        minChargeCelsius: 5, maxChargeCelsius: 40, minDischargeCelsius: 5,
        maxDischargeCelsius: 40, maturity: "Established chemistry · conceptual tank / stack equivalent")

    private static func curve(_ volts: [Double]) -> [VoltagePoint] {
        let fractions: [Double] = [0, 0.1, 0.3, 0.6, 0.9, 1]
        return zip(fractions, volts).map { VoltagePoint($0.0, $0.1) }
    }
}
