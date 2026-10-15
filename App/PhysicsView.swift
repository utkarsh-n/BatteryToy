import SwiftUI
import BatteryCore

struct PhysicsView: View {
    let preset: CellPreset
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { LabStyle.accent(preset) }

    var body: some View {
        LabScroll {
            introduction
            materials
            transport
            transformations
            charging
            equations
            scaling
            limits
            sources
        }
        .navigationTitle("Inside the cell")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { dismiss() }
                    .accessibilityIdentifier("physicsDone")
            }
        }
        .textSelection(.enabled)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(preset.chemistry.title)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(accent)
            Text(preset.mechanism).font(.body).fixedSize(horizontal: false, vertical: true)
            Text(preset.maturity).font(.caption).foregroundStyle(LabStyle.muted)
        }.padding(.top, 12)
    }

    private var materials: some View {
        LabPanel(title: "The active materials", icon: "atom") {
            material("Negative electrode", value: negativeElectrode)
            material("Positive electrode", value: positiveElectrode)
            material("Electrolyte", value: preset.chemistry.electrolyte)
            Text("Electrode names here use the discharge convention: negative is the anode and positive is the cathode. Their oxidation and reduction roles reverse during charging.")
                .font(.caption).foregroundStyle(LabStyle.muted)
        }
    }

    private var transport: some View {
        LabPanel(title: "Two paths, one circuit", icon: "point.3.connected.trianglepath.dotted") {
            Label("Electrons travel through the external wire and load.", systemImage: "arrow.turn.up.right")
                .foregroundStyle(LabStyle.cyan)
            Label("\(preset.chemistry.ionSymbol) carries charge inside the electrolyte.", systemImage: "arrow.left.arrow.right")
                .foregroundStyle(LabStyle.violet)
            Text(transportDetail).font(.subheadline).foregroundStyle(LabStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var transformations: some View {
        LabPanel(title: "Discharge • the chemical story", icon: "arrow.trianglehead.2.clockwise.rotate.90") {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.system(.caption, design: .monospaced, weight: .bold))
                        .frame(width: 27, height: 27)
                        .background(accent.opacity(0.14), in: .circle).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(stage.title).font(.subheadline.weight(.semibold))
                        Text(stage.detail).font(.subheadline).foregroundStyle(LabStyle.muted)
                    }
                }.accessibilityElement(children: .combine)
            }
            Text("These are explanatory transformations. The hologram is a schematic; the terminal model does not solve local concentrations, crystal boundaries, or individual reaction rates.")
                .font(.caption).foregroundStyle(LabStyle.muted)
        }
    }

    private var charging: some View {
        LabPanel(title: "How charging differs", icon: "bolt.badge.clock") {
            Text(preset.chemistry.chargeProtocol).font(.headline).foregroundStyle(accent)
            Text(chargeDetail).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text("The live phase label describes the controller's operating stage. It is separate from a material's chemical or crystal phase.")
                .font(.caption).foregroundStyle(LabStyle.muted)
        }
    }

    private var equations: some View {
        LabPanel(title: "The live model", icon: "function") {
            equation("Charge balance", formula: "dz/dt = −I / (3600 Q)",
                     explanation: "z is fractional chemical SOC, I is amperes and Q is available chemical capacity in ampere-hours. Positive current means discharge. During charge, an efficiency factor reduces the charge stored.")
            equation("Terminal voltage", formula: "V = U(z) − I(R₀ + Rₐ) − vₚ",
                     explanation: "U is open-circuit voltage in volts. R₀ gives immediate sag in ohms; vₚ is slower polarization in volts. Rₐ is an extra illustrative charge-acceptance resistance used only for lead-acid charging. During charge I is negative, so terminal voltage rises above U.")
            equation("Relaxation", formula: "dvₚ/dt = (I Rₚ − vₚ) / τ",
                     explanation: "Rₚ is polarization resistance in ohms and τ is its relaxation time in seconds. After opening the circuit, vₚ decays toward zero. Voltage can rebound while chemical SOC stays the same.")
            equation("Lumped temperature", formula: "Cθ dT/dt = Pheat − (T − Ta)/Rθ",
                     explanation: "Cθ is heat capacity in J/K; Rθ is thermal resistance in K/W; Ta is ambient temperature. Ohmic and RC losses warm one uniform-temperature cell. NiMH reaction heat and full-inventory float losses use illustrative proxies. The surroundings remove heat.")
            equation("Energy delivered", formula: "E = ∫ V I dt / 3600",
                     explanation: "With time in seconds, energy is watt-hours. Ah counts charge; Wh counts energy. Multiplying nominal V by Ah gives a nominal energy reference, not the exact integral under a changing load.")
        }
    }

    private var scaling: some View {
        LabPanel(title: "From one cell to a system", icon: "square.grid.3x3") {
            Text("For identical, balanced cells of this example:").font(.subheadline)
            scaleRow("One cell", voltage: preset.nominalVoltage, capacity: preset.capacityAh)
            scaleRow("4 in series", voltage: 4 * preset.nominalVoltage, capacity: preset.capacityAh)
            scaleRow("4 series × 2 parallel", voltage: 4 * preset.nominalVoltage, capacity: 2 * preset.capacityAh)
            Text("Series adds voltage; parallel adds ampere-hours. Pack resistance is Rcell × Ns/Np. Every cell still experiences its own current and temperature. This ideal scaling omits imbalance, interconnect losses and pack cooling geometry.")
                .font(.caption).foregroundStyle(LabStyle.muted)
            if preset.chemistry == .vanadiumFlow {
                Text("Flow is different: more electrolyte inventory extends duration, while electrode area and the stack govern power. A larger tank does not automatically make a more powerful stack.")
                    .font(.subheadline).foregroundStyle(accent)
            }
            if preset.formFactor == .nano {
                Text("Nano describes a geometry, not a new chemistry. Shorter transport distances can improve power, but interfaces, current collectors and electrolyte still take space. This conceptual cell's absolute capacity and thermal parameters are illustrative.")
                    .font(.subheadline).foregroundStyle(accent)
            }
        }
    }

    private var limits: some View {
        LabPanel(title: "Why choose this chemistry", icon: "scope") {
            ForEach(preset.strengths, id: \.self) { text in
                Label(text, systemImage: "plus.circle").foregroundStyle(accent)
            }
            ForEach(preset.tradeoffs, id: \.self) { text in
                Label(text, systemImage: "minus.circle").foregroundStyle(LabStyle.muted)
            }
            Divider().overlay(LabStyle.muted.opacity(0.2))
            Text(preset.modelScope).font(.subheadline)
            Text("One RC branch approximates terminal dynamics. This model omits spatial diffusion, detailed electrode kinetics, phase-boundary motion, hysteresis, calibrated lifetime, entropy heat and thermal runaway. Cold and rate limits estimate accessible charge; warming or resting does not create chemical charge. The controls teach trends within each preset's modeled operating window.")
                .font(.caption).foregroundStyle(LabStyle.muted)
        }
    }

    private var sources: some View {
        LabPanel(title: "Primary references", icon: "book.closed") {
            Text("These sources explain the chemistry and representative devices. They are not fitted parameter datasets for this simulator.")
                .font(.caption).foregroundStyle(LabStyle.muted)
            ForEach(preset.sources, id: \.self) { source in
                if let url = URL(string: source.url) {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(source.title).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.right")
                        }.font(.subheadline).padding(.vertical, 8)
                    }.foregroundStyle(accent)
                }
            }
        }
    }

    private func material(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(LabStyle.muted)
            Text(value).font(.subheadline.weight(.medium))
        }.accessibilityElement(children: .combine)
    }

    private func equation(_ title: String, formula: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(formula).font(.system(.callout, design: .monospaced)).foregroundStyle(accent)
            Text(explanation).font(.caption).foregroundStyle(LabStyle.muted)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func scaleRow(_ title: String, voltage: Double, capacity: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.medium))
            Text("\(quantity(voltage, "V")) · \(quantity(capacity, "Ah")) · \(quantity(voltage * capacity, "Wh")) nominal")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(accent)
        }.accessibilityElement(children: .combine)
    }

    private var transportDetail: String {
        switch preset.chemistry {
        case .vanadiumFlow:
            "Pumps bring active electrolyte from the tanks to the electrodes. The membrane conducts charge-balancing ions while ideally keeping the two vanadium inventories apart. Their unwanted crossover is a loss mechanism."
        case .alkaline, .nickelMetalHydride:
            "Hydroxide is produced at the positive electrode and consumed at the negative electrode during discharge. This is not a lithium-ion shuttle. The separator prevents an electronic short while allowing ionic transport."
        case .leadAcid:
            "Sulfate participates at both electrodes and sulfuric acid is diluted during discharge. The internal ionic path balances the external electronic current."
        case .solidState:
            "Lithium ions migrate through a solid ion conductor. The solid electrolyte must block electron flow between electrodes; there is no liquid sloshing inside this example."
        default:
            "During discharge, lithium or sodium leaves the negative electrode and is taken up or reacts at the positive electrode. The separator conducts ions through electrolyte but blocks an electronic short. Charging a rechargeable cell reverses the overall transfer."
        }
    }

    private var chargeDetail: String {
        switch preset.chemistry {
        case .alkaline, .lithiumPrimary:
            "The primary reaction is not designed for safe repeated reversal. Battery Toy blocks charging current. A primary coin cell and a rechargeable coin cell can share a shape while having different chemistry and voltage limits."
        case .nickelMetalHydride:
            "Real chargers look for a voltage peak and small fall (−ΔV), temperature rise and time limits. Here an illustrative near-full voltage peak, heat proxy and timer produce those signals. SOC thresholds guard termination. These signals are not calibrated −ΔV or gas-recombination predictions."
        case .leadAcid:
            "Bulk supplies current, absorption holds a higher voltage while acceptance falls, and float uses a lower temperature-compensated ceiling. A small maintenance current tops up charge; input beyond full inventory becomes modeled heat. Real settings depend on construction. Long-term corrosion, gas evolution and electrolyte loss are not predicted."
        case .vanadiumFlow:
            "Current changes the oxidation states of the tank inventory at the stack electrodes. This model limits current at its voltage ceiling and stops at its inventory limit. Pump loss, electrolyte concentration, flow rate and membrane crossover are not solved."
        case .lithiumSulfur:
            "Sulfur conversion cells require an electrolyte- and design-specific charge protocol. This example uses current control and a voltage ceiling to illustrate terminal response. It does not predict polysulfide shuttle, precipitation or research-cell lifetime."
        case .solidState:
            "The label solid-state describes the electrolyte. The electrodes and interfaces determine the required charging protocol. This example uses a modeled current stage and voltage ceiling; solid electrolyte alone does not guarantee safe unlimited charging."
        default:
            "Precharge uses a reduced current at low SOC. Constant current fills the cell until the terminal-voltage ceiling is reached; constant voltage then reduces current and stops. The voltage ceiling and current limits differ by chemistry and by device."
        }
    }

    private var stages: [ChemistryStoryStage] {
        switch preset.chemistry {
        case .solidState:
            preset.formFactor == .nano
                ? [.init("Lithium leaves a silicon host", "In the cited nanoscale architecture, lithium is released from a silicon negative electrode and electrons leave through the wire."),
                   .init("Ions cross a deposited solid film", "Li⁺ moves through a conformal LiPON-family electrolyte. Its thin geometry shortens transport distance; interfaces remain crucial."),
                   .init("LiCoO₂ takes up lithium", "The positive host receives ions and external electrons. This research-inspired nanocell's absolute electrical and thermal parameters are conceptual.")]
                : [.init("Lithium metal releases charge", "The lithium-metal negative electrode is oxidized; electrons leave through the wire."),
                   .init("Ions cross a solid", "Li⁺ moves through the LiPON electrolyte toward the positive host. Interfaces and film thickness affect transport."),
                   .init("LiCoO₂ takes up lithium", "The positive host receives ions and external electrons. Charging reverses the transfer within device-specific limits.")]
        case .alkaline:
            [.init("Zinc is oxidized", "Zinc supplies external electrons and is converted toward zinc oxide."),
             .init("Manganese dioxide is reduced", "MnO₂ accepts electrons and forms MnOOH. Hydroxide links the half-reactions inside the cell."),
             .init("The discharge curve slopes", "Reaction products, falling reactant availability and increasing resistance change the voltage. Lower drain can deliver more usable charge before cutoff.")]
        case .lithiumPrimary:
            [.init("Lithium metal is oxidized", "The negative electrode supplies electrons and Li⁺."),
             .init("MnO₂ takes up lithium", "Lithium insertion and reduction of the manganese-oxide host sustain a relatively flat voltage over much of discharge."),
             .init("The inventory is consumed", "This primary reaction is not a rechargeable lithium-ion cycle. A coin cell favors low drain and long shelf service over large power pulses.")]
        case .nickelMetalHydride:
            [.init("Stored hydrogen is released", "The metal hydride negative electrode releases hydrogen into the reaction and supplies electrons."),
             .init("Nickel changes oxidation state", "NiOOH is reduced toward Ni(OH)₂ at the positive electrode. Hydroxide ions balance the half-reactions."),
             .init("A plateau ends in a knee", "The fairly flat voltage supports electronics, but voltage alone gives a poor SOC estimate. Charging reabsorbs hydrogen into the alloy.")]
        case .leadAcid:
            [.init("Both plates form lead sulfate", "Lead and lead dioxide react with sulfuric acid; both electrodes become PbSO₄ during discharge."),
             .init("The acid is diluted", "The net reaction produces water. Electrolyte concentration and plate state change with discharge."),
             .init("Charging restores the plates", "Charging reverses the overall reaction. Long storage while discharged can form difficult-to-reverse sulfate crystals.")]
        case .lithiumIonNMC:
            [.init("Lithium leaves graphite", "Li⁺ leaves the negative host; electrons power the external load."),
             .init("NMC receives lithium", "Lithium is inserted into the positive oxide and its transition metals change oxidation state."),
             .init("The hosts trade inventory", "Intercalation stores energy without consuming the host every cycle. Diffusion, interfaces and structural changes still limit rate and lifetime.")]
        case .lithiumIronPhosphate:
            [.init("Lithium leaves graphite", "The negative host releases lithium ions and electrons during discharge."),
             .init("Li-rich and Li-poor regions coexist", "The positive electrode transforms between FePO₄ and LiFePO₄. Two-phase behavior helps create the broad voltage plateau."),
             .init("The plateau reaches its edge", "Voltage changes sharply near the available-inventory limits. This model represents the plateau with an OCV curve; it does not track phase boundaries or hysteresis.")]
        case .sodiumIon:
            [.init("Sodium leaves hard carbon", "The negative electrode releases stored sodium and electrons."),
             .init("A sodium host receives ions", "This representative positive electrode uses a Prussian-white host. Other sodium-ion cells use different hosts and have different voltage curves."),
             .init("An ambient-temperature shuttle", "This is a sodium-ion cell, distinct from high-temperature molten sodium–sulfur. Hard-carbon storage can involve several mechanisms rather than one ideal crystal lattice.")]
        case .lithiumSulfur:
            [.init("Sulfur enters the upper plateau", "Sulfur is reduced toward soluble long-chain lithium polysulfides in a typical liquid-electrolyte conversion cell."),
             .init("The lower plateau converts sulfides", "Further reduction produces shorter-chain species and ultimately solid lithium sulfide. Nucleation and precipitation shape the voltage."),
             .init("Shuttle competes with storage", "Dissolved polysulfides can move to the lithium electrode and react parasitically. This can cause self-discharge and lower efficiency; it is described here but not dynamically solved.")]
        case .vanadiumFlow:
            [.init("Negative vanadium gives up an electron", "V²⁺ is oxidized to V³⁺ at the negative electrode during discharge."),
             .init("Positive vanadium receives it", "V⁵⁺ is reduced toward V⁴⁺ at the positive electrode. Charge-balancing ions cross the membrane."),
             .init("Tanks carry the energy inventory", "Pumped dissolved reactants bring charge to the stack. Increasing electrolyte volume can extend discharge duration without changing the electrode stack's power rating.")]
        }
    }

    private var negativeElectrode: String {
        if preset.formFactor == .nano { return "Silicon host · cited research architecture" }
        if preset.formFactor == .thinFilm { return "Lithium metal · thin-film example" }
        return preset.chemistry.anode
    }

    private var positiveElectrode: String {
        if preset.chemistry == .solidState { return "Lithium cobalt oxide · LiCoO₂ example" }
        return preset.chemistry.cathode
    }
}

private struct ChemistryStoryStage {
    let title: String
    let detail: String
    init(_ title: String, _ detail: String) { self.title = title; self.detail = detail }
}
