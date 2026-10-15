import SwiftUI
import BatteryCore

struct SpecimenPicker: View {
    var lab: BatteryLab
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var results: [CellPreset] { CellPreset.all.filter { search.isEmpty || "\($0.name) \($0.chemistry.title) \($0.scaleName)".localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List(results) { preset in
            Button { lab.select(preset); dismiss() } label: {
                SpecimenRow(preset: preset, selected: preset.id == lab.preset.id)
            }.buttonStyle(.plain).accessibilityIdentifier("specimen-option-\(preset.id)").listRowBackground(LabStyle.panel)
        }
        .scrollContentBackground(.hidden).background(LabStyle.background)
        .searchable(text: $search, prompt: "Chemistry, shape, or scale")
        .navigationTitle("Choose a battery")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

struct SpecimenRow: View {
    var preset: CellPreset
    var selected = false
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: LabStyle.symbol(preset)).font(.title2).foregroundStyle(LabStyle.accent(preset))
                .frame(width: 48, height: 56)
                .background(LabStyle.accent(preset).opacity(0.07), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(preset.name).font(.headline).foregroundStyle(LabStyle.ink)
                Text(preset.chemistry.title).font(.subheadline).foregroundStyle(LabStyle.muted)
                Text("\(preset.scaleName) · \(quantity(preset.nominalEnergyWh, "Wh"))")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(LabStyle.accent(preset))
            }
            Spacer(minLength: 0)
            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(LabStyle.cyan) }
        }.padding(.vertical, 5).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}

struct AtlasView: View {
    var lab: BatteryLab
    var openLab: () -> Void
    @State private var search = ""
    @State private var filter = "All"
    private let filters = ["All", "Rechargeable", "Primary", "Research", "Large scale"]
    private var results: [CellPreset] {
        CellPreset.all.filter { preset in
            let match = search.isEmpty || "\(preset.name) \(preset.chemistry.title) \(preset.useCases.joined(separator: " "))".localizedCaseInsensitiveContains(search)
            let category = switch filter {
            case "Rechargeable": preset.isRechargeable
            case "Primary": !preset.isRechargeable
            case "Research": ["nano-solid-state", "lithium-sulfur"].contains(preset.id)
            case "Large scale": preset.formFactor.rawValue == "pack" || preset.formFactor.rawValue == "flow"
            default: true
            }
            return match && category
        }
    }
    var body: some View {
        LabScroll {
            VStack(alignment: .leading, spacing: 8) {
                Text("Energy, in every shape.").font(.system(.largeTitle, design: .rounded, weight: .medium))
                Text("Twelve representative designs. Explore the reaction, then put the cell under load.")
                    .font(.subheadline).foregroundStyle(LabStyle.muted)
            }.padding(.top, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { label in
                        Button(label) { filter = label }.buttonStyle(GlassControlStyle(prominent: filter == label))
                    }
                }.padding(.vertical, 5)
            }
            LazyVStack(spacing: 12) {
                ForEach(results) { preset in
                    NavigationLink {
                        SpecimenDetail(preset: preset) { lab.select(preset); openLab() }
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            SpecimenRow(preset: preset)
                            Text(preset.subtitle).font(.subheadline).foregroundStyle(LabStyle.muted).fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text(preset.isRechargeable ? "↔ Rechargeable" : "→ Primary").font(.caption).foregroundStyle(LabStyle.accent(preset))
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(LabStyle.muted)
                            }
                        }.padding(16).background(LabStyle.panel, in: .rect(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("atlas-specimen-\(preset.id)")
                }
            }
        }
        .navigationTitle("Atlas").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Find a battery or use case")
    }
}

struct SpecimenDetail: View {
    var preset: CellPreset
    var explore: () -> Void
    var body: some View {
        LabScroll {
            SpecimenRow(preset: preset).padding(.top, 14)
            Text(preset.subtitle).font(.system(.title2, design: .rounded, weight: .medium))
            Button { explore() } label: { Label("Open in the lab", systemImage: "cube.transparent").frame(maxWidth: .infinity) }
                .buttonStyle(GlassControlStyle(prominent: true, tint: LabStyle.accent(preset)))
            LabPanel(title: "Where it belongs", icon: "location") {
                ForEach(preset.useCases, id: \.self) { Label($0, systemImage: "arrow.up.right").font(.subheadline) }
            }
            LabPanel(title: "Why it's special", icon: "sparkles") {
                ForEach(preset.strengths, id: \.self) { Label($0, systemImage: "plus.circle").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
            }
            LabPanel(title: "The tradeoff", icon: "scale.3d") {
                ForEach(preset.tradeoffs, id: \.self) { Text($0).font(.subheadline).foregroundStyle(LabStyle.muted).fixedSize(horizontal: false, vertical: true) }
            }
            LabPanel(title: "Representative configuration", icon: "square.grid.3x3") {
                HStack {
                    Readout(title: "Voltage", value: quantity(preset.packNominalVoltage, "V"))
                    Readout(title: "Capacity", value: quantity(preset.packCapacityAh, "Ah"))
                    Readout(title: "Energy", value: quantity(preset.nominalEnergyWh, "Wh"))
                }
                Text("\(preset.series) cells in series · \(preset.parallel) parallel strings. Balanced cells assumed.").font(.caption).foregroundStyle(LabStyle.muted)
            }
            NavigationLink { PhysicsView(preset: preset) } label: { Label("Chemistry, equations & sources", systemImage: "atom") }
                .buttonStyle(GlassControlStyle(tint: LabStyle.accent(preset))).accessibilityIdentifier("open-chemistry")
        }.navigationTitle(preset.name).navigationBarTitleDisplayMode(.inline)
    }
}
