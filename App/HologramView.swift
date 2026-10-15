import SwiftUI

/// An inspectable transport schematic, with a motion-lit shell rather than literal material optics.
/// Layer indices are 0: anode, 1: separator, 2: cathode.
struct HologramView: View {
    let charge: Double
    let current: Double
    let temperature: Double
    let form: String
    let accent: Color
    let phase: String
    let motion: MotionLight
    let isRunning: Bool
    let exploded: Bool
    @Binding var selectedLayer: Int?
    var carrierDirection: Double = 1
    var carrierLabel: String = "IONS"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var inspectedYaw: Double = 0
    @State private var inspectedPitch: Double = 0
    @GestureState private var inspectionDrag: CGSize = .zero

    private var lightX: Double { reduceMotion ? 0 : motion.x }
    private var lightY: Double { reduceMotion ? 0 : motion.y }
    private var yaw: Double { inspectedYaw + Double(inspectionDrag.width) / 180 + lightX * 0.14 }
    private var pitch: Double { inspectedPitch - Double(inspectionDrag.height) / 280 + lightY * 0.08 }
    private var boundedCharge: Double { max(0, min(1, charge.isFinite ? charge : 0)) }

    var body: some View {
        let reflectedLightX = lightX
        let reflectedLightY = lightY
        let reflectedYaw = yaw
        let reflectedPitch = pitch
        return GeometryReader { geometry in
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning || reduceMotion)) { timeline in
                    let time = reduceMotion || !isRunning ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                        let renderer = HologramRenderer(
                            size: size, charge: boundedCharge, current: current,
                            temperature: temperature, form: form, accent: accent,
                            time: time, lightX: reflectedLightX, lightY: reflectedLightY,
                            yaw: reflectedYaw, pitch: reflectedPitch, exploded: exploded,
                            selectedLayer: selectedLayer, solid: reduceTransparency,
                            moving: isRunning && !reduceMotion,
                            carrierDirection: carrierDirection, carrierLabel: carrierLabel,
                            highContrast: contrast == .increased
                        )
                        renderer.draw(in: &context)
                    }
                    .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        stageBadge("TRANSPORT", symbol: "atom")
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(Int((boundedCharge * 100).rounded()))%")
                                .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                            Text("STATE OF CHARGE")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.54))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 5)
                    Spacer()
                    layerControls
                    HStack(spacing: 5) {
                        Image(systemName: reduceMotion ? "hand.draw" : "move.3d")
                        Text(reduceMotion ? "Drag to inspect" : "Drag to inspect · Tilt for light")
                        Text("·")
                        Text("Schematic")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }
                .allowsHitTesting(true)
            }
            .contentShape(Rectangle())
            .gesture(inspectionGesture)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Battery transport schematic")
            .accessibilityValue("\(Int(boundedCharge * 100)) percent charge. \(phase). \(current < 0 ? "Charging" : current > 0 ? "Discharging" : "At rest").")
            .accessibilityAction(named: Text("Rotate left")) { inspectedYaw = max(-0.65, inspectedYaw - 0.15) }
            .accessibilityAction(named: Text("Rotate right")) { inspectedYaw = min(0.65, inspectedYaw + 0.15) }
            .accessibilityAction(named: Text("Reset perspective")) { inspectedYaw = 0; inspectedPitch = 0 }
            .accessibilityIdentifier("battery-hologram")
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sensoryFeedback(.selection, trigger: selectedLayer)
    }

    private var inspectionGesture: some Gesture {
        DragGesture(minimumDistance: 7)
            .updating($inspectionDrag) { value, state, _ in state = value.translation }
            .onEnded { value in
                inspectedYaw = max(-0.65, min(0.65, inspectedYaw + Double(value.translation.width) / 180))
                inspectedPitch = max(-0.35, min(0.35, inspectedPitch - Double(value.translation.height) / 280))
            }
    }

    private func stageBadge(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
            Text(title).font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1.3)
        }
        .foregroundStyle(accent.opacity(0.95))
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var layerControls: some View {
        if reduceTransparency {
            HStack(spacing: 8) {
                layerButton(0, "Anode", color: HologramRenderer.anodeColor)
                layerButton(1, "Separator", color: HologramRenderer.separatorColor)
                layerButton(2, "Cathode", color: HologramRenderer.cathodeColor)
            }
        } else if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    layerButton(0, "Anode", color: HologramRenderer.anodeColor)
                    layerButton(1, "Separator", color: HologramRenderer.separatorColor)
                    layerButton(2, "Cathode", color: HologramRenderer.cathodeColor)
                }
            }
        } else {
            HStack(spacing: 8) {
                layerButton(0, "Anode", color: HologramRenderer.anodeColor)
                layerButton(1, "Separator", color: HologramRenderer.separatorColor)
                layerButton(2, "Cathode", color: HologramRenderer.cathodeColor)
            }
        }
    }

    @ViewBuilder
    private func layerButton(_ index: Int, _ title: String, color: Color) -> some View {
        let isSelected = selectedLayer == index
        if reduceTransparency {
            Button {
                selectedLayer = isSelected ? nil : index
            } label: {
                layerLabel(title, color: color, selected: isSelected)
            }
            .buttonStyle(.plain)
            .background(isSelected ? color.opacity(0.32) : Color(red: 0.10, green: 0.14, blue: 0.21), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? color : Color.white.opacity(0.3), lineWidth: 1))
            .accessibilityLabel("Inspect \(title.lowercased())")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("inspect-layer-\(index)")
        } else if #available(iOS 26.0, *) {
            Button {
                selectedLayer = isSelected ? nil : index
            } label: {
                layerLabel(title, color: color, selected: isSelected)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(isSelected ? color.opacity(0.25) : .clear).interactive(), in: .capsule)
            .accessibilityLabel("Inspect \(title.lowercased())")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("inspect-layer-\(index)")
        } else {
            Button {
                selectedLayer = isSelected ? nil : index
            } label: {
                layerLabel(title, color: color, selected: isSelected)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel("Inspect \(title.lowercased())")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("inspect-layer-\(index)")
        }
    }

    private func layerLabel(_ title: String, color: Color, selected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.system(size: 11, weight: selected ? .semibold : .medium))
        }
        .foregroundStyle(.white.opacity(selected ? 1 : 0.82))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
    }
}

private struct HologramRenderer {
    static let anodeColor = Color(red: 0.22, green: 0.81, blue: 1)
    static let separatorColor = Color(red: 0.66, green: 0.76, blue: 1)
    static let cathodeColor = Color(red: 0.96, green: 0.42, blue: 0.79)

    let size: CGSize
    let charge: Double
    let current: Double
    let temperature: Double
    let form: String
    let accent: Color
    let time: Double
    let lightX: Double
    let lightY: Double
    let yaw: Double
    let pitch: Double
    let exploded: Bool
    let selectedLayer: Int?
    let solid: Bool
    let moving: Bool
    let carrierDirection: Double
    let carrierLabel: String
    let highContrast: Bool

    private var scale: Double { min(Double(size.width) / 360, Double(size.height) / 350) }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: min(size.height * 0.455, size.height - 115)) }
    private var direction: Double { (current < 0 ? -1 : 1) * carrierDirection }
    private var working: Bool { current.isFinite && current != 0 }
    private var kineticTime: Double { time.truncatingRemainder(dividingBy: 600) }

    func draw(in context: inout GraphicsContext) {
        drawField(in: &context)
        drawDial(in: &context)
        drawElectronCircuit(in: &context)
        switch form {
        case "cylinder": drawCylinder(in: &context)
        case "coin": drawCoin(in: &context)
        case "thinFilm": drawThinFilm(in: &context)
        case "nano": drawNano(in: &context)
        case "prismatic", "prism": drawPrismatic(in: &context)
        case "pack": drawPack(in: &context)
        case "flow": drawFlow(in: &context)
        default: drawPouch(in: &context)
        }
        drawIonTransport(in: &context)
        drawLight(in: &context)
        drawLabels(in: &context)
    }

    private func project(_ point: V3) -> CGPoint {
        let ya = yaw + 0.18
        let pi = pitch + (form == "coin" ? -0.75 : -0.10)
        let rx = point.x * cos(ya) + point.z * sin(ya)
        let rz = -point.x * sin(ya) + point.z * cos(ya)
        let ry = point.y * cos(pi) - rz * sin(pi)
        let depth = point.y * sin(pi) + rz * cos(pi)
        let perspective = 420 / (420 + depth)
        return CGPoint(x: Double(center.x) + rx * perspective * scale, y: Double(center.y) + ry * perspective * scale)
    }

    private func path(_ points: [V3], close: Bool = true) -> Path {
        var result = Path()
        guard let first = points.first else { return result }
        result.move(to: project(first))
        for point in points.dropFirst() { result.addLine(to: project(point)) }
        if close { result.closeSubpath() }
        return result
    }

    private func ellipse(radiusX: Double, radiusZ: Double, y: Double, x: Double = 0, z: Double = 0) -> Path {
        path((0..<65).map { step in
            let angle = Double(step) / 64 * .pi * 2
            return V3(x + cos(angle) * radiusX, y, z + sin(angle) * radiusZ)
        })
    }

    private func stroke(_ path: Path, color: Color, width: Double = 1, opacity: Double = 1, context: inout GraphicsContext) {
        context.stroke(path, with: .color(color.opacity(highContrast ? max(0.48, opacity) : opacity)), lineWidth: width * scale * (highContrast ? 1.22 : 1))
    }

    private func plate(x: Double, width: Double, height: Double, depth: Double, color: Color, index: Int, context: inout GraphicsContext) {
        let displacement = exploded ? Double(index - 1) * 24 : 0
        let position = x + displacement
        let face = path([
            V3(position - width / 2, -height / 2, -depth / 2), V3(position + width / 2, -height / 2, -depth / 2),
            V3(position + width / 2, height / 2, -depth / 2), V3(position - width / 2, height / 2, -depth / 2)
        ])
        let selected = selectedLayer == index
        context.fill(face, with: .linearGradient(
            Gradient(colors: [color.opacity(solid ? 0.8 : selected ? 0.46 : 0.31), color.opacity(solid ? 0.42 : 0.09)]),
            startPoint: project(V3(position - 24, -height / 2, 0)), endPoint: project(V3(position + 24, height / 2, 0))
        ))
        stroke(face, color: color, width: selected ? 2.0 : 0.85, opacity: selected ? 1 : 0.7, context: &context)
        let side = path([
            V3(position + width / 2, -height / 2, -depth / 2), V3(position + width / 2, -height / 2, depth / 2),
            V3(position + width / 2, height / 2, depth / 2), V3(position + width / 2, height / 2, -depth / 2)
        ])
        context.fill(side, with: .color(color.opacity(solid ? 0.35 : 0.14)))
        stroke(side, color: color, opacity: 0.45, context: &context)
        for row in 0..<9 {
            let yy = -height * 0.4 + Double(row) * height * 0.1
            stroke(path([V3(position - width * 0.36, yy, -depth / 2 - 1), V3(position + width * 0.36, yy, -depth / 2 - 1)], close: false), color: color, opacity: selected ? 0.55 : 0.18, context: &context)
        }
    }

    private func drawField(in context: inout GraphicsContext) {
        let radius = 128 * scale
        let rect = CGRect(x: Double(center.x) - radius, y: Double(center.y) - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [accent.opacity(solid ? 0.16 : 0.10), accent.opacity(0.018), .clear]),
            center: center, startRadius: 0, endRadius: radius
        ))
        for row in -3...3 {
            let y = Double(center.y) + Double(row) * 31 * scale
            var line = Path()
            line.move(to: CGPoint(x: Double(center.x) - 125 * scale, y: y))
            line.addLine(to: CGPoint(x: Double(center.x) + 125 * scale, y: y))
            context.stroke(line, with: .color(accent.opacity(row == 0 ? 0.09 : 0.035)), lineWidth: 0.5)
        }
        let floor = CGRect(x: Double(center.x) - 70 * scale, y: Double(center.y) + 83 * scale, width: 140 * scale, height: 19 * scale)
        context.stroke(Path(ellipseIn: floor), with: .color(accent.opacity(0.18)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
        context.fill(Path(ellipseIn: floor), with: .radialGradient(Gradient(colors: [accent.opacity(0.15), .clear]), center: CGPoint(x: center.x, y: Double(center.y) + 92 * scale), startRadius: 0, endRadius: 70 * scale))
    }

    private func drawDial(in context: inout GraphicsContext) {
        let radius = 126 * scale
        let angularStart = Double.pi * 0.72
        let sweep = Double.pi * 1.56
        let orbitRect = CGRect(x: Double(center.x) - radius, y: Double(center.y) - radius, width: radius * 2, height: radius * 2)
        var track = Path()
        track.addArc(center: center, radius: radius, startAngle: .radians(angularStart), endAngle: .radians(angularStart + sweep), clockwise: false)
        context.stroke(track, with: .color(.white.opacity(0.09)), lineWidth: 2.5 * scale)
        var charged = Path()
        charged.addArc(center: center, radius: radius, startAngle: .radians(angularStart), endAngle: .radians(angularStart + sweep * charge), clockwise: false)
        context.stroke(charged, with: .conicGradient(Gradient(colors: [Self.anodeColor, accent, Self.cathodeColor]), center: center), style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
        for tick in 0...60 {
            let theta = angularStart + sweep * Double(tick) / 60
            let long = tick % 5 == 0
            var line = Path()
            line.move(to: CGPoint(x: Double(center.x) + cos(theta) * (radius + 6 * scale), y: Double(center.y) + sin(theta) * (radius + 6 * scale)))
            line.addLine(to: CGPoint(x: Double(center.x) + cos(theta) * (radius + (long ? 13 : 9) * scale), y: Double(center.y) + sin(theta) * (radius + (long ? 13 : 9) * scale)))
            context.stroke(line, with: .color(.white.opacity(long ? 0.28 : 0.10)), lineWidth: (long ? 0.9 : 0.5) * scale)
        }
        let theta = angularStart + sweep * charge
        let endpoint = CGPoint(x: Double(center.x) + cos(theta) * radius, y: Double(center.y) + sin(theta) * radius)
        context.fill(Path(ellipseIn: CGRect(x: endpoint.x - 3 * scale, y: endpoint.y - 3 * scale, width: 6 * scale, height: 6 * scale)), with: .color(.white))
        // A reflected edge follows the measured light direction independently of SOC.
        var gleam = Path()
        let lightAngle = -Double.pi / 2 + lightX * 1.2 + lightY * 0.25
        gleam.addArc(center: center, radius: radius - 5 * scale, startAngle: .radians(lightAngle - 0.12), endAngle: .radians(lightAngle + 0.19), clockwise: false)
        context.stroke(gleam, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.9), Self.anodeColor.opacity(0.7), .clear]), startPoint: CGPoint(x: orbitRect.minX, y: orbitRect.minY), endPoint: CGPoint(x: orbitRect.maxX, y: orbitRect.maxY)), lineWidth: 1.2 * scale)
    }

    private func drawPouch(in context: inout GraphicsContext) {
        let shell = path([V3(-59, -69, -15), V3(59, -69, -15), V3(65, -61, -15), V3(65, 62, -15), V3(55, 71, -15), V3(-55, 71, -15), V3(-65, 62, -15), V3(-65, -61, -15)])
        shellFill(shell, context: &context)
        plate(x: -29, width: 42, height: 119, depth: 20, color: Self.anodeColor, index: 0, context: &context)
        plate(x: 0, width: 7, height: 121, depth: 23, color: Self.separatorColor, index: 1, context: &context)
        plate(x: 29, width: 42, height: 119, depth: 20, color: Self.cathodeColor, index: 2, context: &context)
        for x in [-32.0, 32.0] {
            let tab = path([V3(x - 9, -83, 0), V3(x + 9, -83, 0), V3(x + 9, -68, 0), V3(x - 9, -68, 0)])
            context.fill(tab, with: .color(.white.opacity(0.14)))
            stroke(tab, color: .white, opacity: 0.58, context: &context)
        }
        let back = path([V3(-59, -69, 15), V3(59, -69, 15), V3(59, 69, 15), V3(-59, 69, 15)])
        stroke(back, color: accent, opacity: 0.22, context: &context)
    }

    private func drawCylinder(in context: inout GraphicsContext) {
        let top = ellipse(radiusX: 54, radiusZ: 29, y: -68)
        let bottom = ellipse(radiusX: 54, radiusZ: 29, y: 68)
        var shell = Path()
        shell.addPath(top)
        shell.addPath(bottom)
        shell.addPath(path([V3(-54, -68, 0), V3(-54, 68, 0)], close: false))
        shell.addPath(path([V3(54, -68, 0), V3(54, 68, 0)], close: false))
        stroke(shell, color: accent, width: 1.2, opacity: 0.65, context: &context)
        plate(x: -26, width: 38, height: 120, depth: 23, color: Self.anodeColor, index: 0, context: &context)
        plate(x: 0, width: 6, height: 124, depth: 26, color: Self.separatorColor, index: 1, context: &context)
        plate(x: 26, width: 38, height: 120, depth: 23, color: Self.cathodeColor, index: 2, context: &context)
        for step in 1...5 {
            let ratio = Double(step) / 6
            stroke(ellipse(radiusX: 52 * ratio, radiusZ: 27 * ratio, y: -66), color: step % 2 == 0 ? Self.cathodeColor : Self.anodeColor, opacity: 0.48, context: &context)
        }
        stroke(ellipse(radiusX: 13, radiusZ: 8, y: -78), color: .white, opacity: 0.75, context: &context)
        let reflection = path([V3(39, -60, -18), V3(43, 55, -18)], close: false)
        stroke(reflection, color: .white, width: 1.5, opacity: 0.4, context: &context)
    }

    private func drawCoin(in context: inout GraphicsContext) {
        // One shallow cell, displayed as a cutaway aperture; this is not a stack of coins.
        let front = ellipse(radiusX: 78, radiusZ: 67, y: -8)
        let back = ellipse(radiusX: 78, radiusZ: 67, y: 18)
        shellFill(front, context: &context)
        stroke(back, color: accent, opacity: 0.48, context: &context)
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 6) {
            stroke(path([V3(cos(angle) * 78, -8, sin(angle) * 67), V3(cos(angle) * 78, 18, sin(angle) * 67)], close: false), color: accent, opacity: 0.18, context: &context)
        }
        let spread = exploded ? 22.0 : 0.0
        for index in 0...2 {
            let color = [Self.anodeColor, Self.separatorColor, Self.cathodeColor][index]
            let y = -14 + Double(index) * 11 + Double(index - 1) * spread
            let aperture = ellipse(radiusX: 64 - Double(index) * 3, radiusZ: 55 - Double(index) * 3, y: y)
            context.fill(aperture, with: .color(color.opacity(solid ? 0.42 : selectedLayer == index ? 0.23 : 0.09)))
            stroke(aperture, color: color, width: selectedLayer == index ? 1.8 : 0.9, opacity: 0.8, context: &context)
            for meridian in -3...3 {
                let x = Double(meridian) * 14
                let half = sqrt(max(0, 1 - x * x / (61 * 61))) * 46
                stroke(path([V3(x, y - 1, -half), V3(x, y - 1, half)], close: false), color: color, opacity: 0.28, context: &context)
            }
        }
        drawText("BUTTON CELL", at: CGPoint(x: center.x, y: Double(center.y) + 63 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func drawThinFilm(in context: inout GraphicsContext) {
        for index in 0...2 {
            let z = Double(index - 1) * (exploded ? 24 : 8)
            let color = [Self.anodeColor, Self.separatorColor, Self.cathodeColor][index]
            let sheet = path([V3(-68, -63, z), V3(56, -63, z), V3(70, -41, z + 12), V3(62, 61, z + 22), V3(-58, 65, z + 22), V3(-68, 43, z)])
            context.fill(sheet, with: .linearGradient(Gradient(colors: [color.opacity(solid ? 0.5 : 0.12), .clear, color.opacity(0.11)]), startPoint: project(V3(-68, -63, z)), endPoint: project(V3(62, 61, z))))
            stroke(sheet, color: color, width: selectedLayer == index ? 1.8 : 0.8, opacity: selectedLayer == index ? 1 : 0.65, context: &context)
            for row in 0..<8 {
                let y = -48 + Double(row) * 14
                stroke(path([V3(-55, y, z - 1), V3(53, y, z + Double(row) * 2)], close: false), color: color, opacity: 0.26, context: &context)
            }
        }
        drawText("DEPOSITED LAYERS", at: CGPoint(x: center.x, y: Double(center.y) + 85 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func drawNano(in context: inout GraphicsContext) {
        for latitude in -2...2 {
            let yy = Double(latitude) * 24
            let radius = sqrt(max(0, 1 - yy * yy / (74 * 74))) * 72
            stroke(ellipse(radiusX: radius, radiusZ: radius * 0.7, y: yy), color: accent, opacity: 0.25, context: &context)
        }
        for side in [-1.0, 1.0] {
            let color = side < 0 ? Self.anodeColor : Self.cathodeColor
            let index = side < 0 ? 0 : 2
            for row in 0..<6 {
                for column in 0..<3 {
                    let x = side * (19 + Double(column) * 16 + (exploded ? 17 : 0))
                    let yy = -48 + Double(row) * 19
                    let zz = sin(Double(row + column) * 1.7) * 13
                    let node = project(V3(x, yy, zz))
                    if column < 2 {
                        stroke(path([V3(x, yy, zz), V3(x + side * 16, yy, sin(Double(row + column + 1) * 1.7) * 13)], close: false), color: color, opacity: 0.32, context: &context)
                    }
                    let r = (selectedLayer == index ? 4.3 : 3.4) * scale
                    context.fill(Path(ellipseIn: CGRect(x: node.x - r, y: node.y - r, width: r * 2, height: r * 2)), with: .radialGradient(Gradient(colors: [.white.opacity(0.8), color.opacity(0.8), color.opacity(0.12)]), center: node, startRadius: 0, endRadius: r))
                }
            }
        }
        plate(x: 0, width: 5, height: 122, depth: 36, color: Self.separatorColor, index: 1, context: &context)
        drawText("NANOSTRUCTURE · ENLARGED", at: CGPoint(x: center.x, y: Double(center.y) + 86 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func drawPack(in context: inout GraphicsContext) {
        let frame = path([V3(-78, -63, -28), V3(78, -63, -28), V3(78, 64, -28), V3(-78, 64, -28)])
        shellFill(frame, context: &context)
        let back = path([V3(-78, -63, 28), V3(78, -63, 28), V3(78, 64, 28), V3(-78, 64, 28)])
        stroke(back, color: accent, opacity: 0.24, context: &context)
        for column in 0..<5 {
            let x = -59 + Double(column) * 29.5
            let color = column < 2 ? Self.anodeColor : column == 2 ? Self.separatorColor : Self.cathodeColor
            let index = column < 2 ? 0 : column == 2 ? 1 : 2
            plate(x: x, width: 21, height: 105, depth: 35, color: color, index: index, context: &context)
            let tab = path([V3(x - 7, -57, -13), V3(x + 7, -57, -13), V3(x + 7, -65, -13), V3(x - 7, -65, -13)])
            stroke(tab, color: .white, opacity: 0.54, context: &context)
        }
        stroke(path([V3(-64, -74, -17), V3(64, -74, -17)], close: false), color: .white, width: 1.2, opacity: 0.6, context: &context)
        drawText("MODULE ARRAY", at: CGPoint(x: center.x, y: Double(center.y) + 84 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func drawPrismatic(in context: inout GraphicsContext) {
        let front = path([V3(-61, -66, -27), V3(61, -66, -27), V3(61, 67, -27), V3(-61, 67, -27)])
        let back = path([V3(-61, -66, 27), V3(61, -66, 27), V3(61, 67, 27), V3(-61, 67, 27)])
        shellFill(front, context: &context)
        stroke(back, color: accent, opacity: 0.4, context: &context)
        for x in [-61.0, 61.0] {
            for y in [-66.0, 67.0] {
                stroke(path([V3(x, y, -27), V3(x, y, 27)], close: false), color: accent, opacity: 0.48, context: &context)
            }
        }
        plate(x: -28, width: 42, height: 119, depth: 31, color: Self.anodeColor, index: 0, context: &context)
        plate(x: 0, width: 7, height: 123, depth: 34, color: Self.separatorColor, index: 1, context: &context)
        plate(x: 28, width: 42, height: 119, depth: 31, color: Self.cathodeColor, index: 2, context: &context)
        for x in [-30.0, 30.0] {
            stroke(ellipse(radiusX: 8, radiusZ: 7, y: -78, x: x), color: .white, width: 1.2, opacity: 0.72, context: &context)
            stroke(path([V3(x - 8, -66, 0), V3(x - 8, -77, 0), V3(x + 8, -77, 0), V3(x + 8, -66, 0)], close: false), color: .white, opacity: 0.5, context: &context)
        }
        drawText("PRISMATIC CELL", at: CGPoint(x: center.x, y: Double(center.y) + 85 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func drawFlow(in context: inout GraphicsContext) {
        for side in [-1.0, 1.0] {
            let x = side * (58 + (exploded ? 10 : 0))
            let color = side < 0 ? Self.anodeColor : Self.cathodeColor
            let index = side < 0 ? 0 : 2
            let top = ellipse(radiusX: 25, radiusZ: 15, y: -53, x: x)
            let bottom = ellipse(radiusX: 25, radiusZ: 15, y: 60, x: x)
            stroke(top, color: color, opacity: 0.7, context: &context)
            stroke(bottom, color: color, opacity: 0.65, context: &context)
            let tank = path([V3(x - 25, -53, 0), V3(x + 25, -53, 0), V3(x + 25, 60, 0), V3(x - 25, 60, 0)])
            context.fill(tank, with: .linearGradient(Gradient(colors: [color.opacity(0.02), color.opacity(solid ? 0.5 : 0.15)]), startPoint: project(V3(x, -53, 0)), endPoint: project(V3(x, 60, 0))))
            stroke(tank, color: color, width: selectedLayer == index ? 1.7 : 0.8, opacity: 0.7, context: &context)
            // Redox state changes with SOC; electrolyte inventory and fill level stay fixed.
            let fluid = ellipse(radiusX: 24, radiusZ: 14, y: -21, x: x)
            context.fill(fluid, with: .color(color.opacity(0.12 + charge * 0.18)))
            stroke(fluid, color: color, opacity: 0.8, context: &context)
            for y in [-43.0, 47.0] {
                let tube = path([V3(x - side * 20, y, 0), V3(side * 15, y, 0), V3(side * 15, y * 0.6, 0)], close: false)
                stroke(tube, color: color, width: 3, opacity: 0.17, context: &context)
                stroke(tube, color: color, width: 0.8, opacity: 0.7, context: &context)
                if working, moving {
                    let progress = (kineticTime * 0.4 + (y < 0 ? 0 : 0.5)).truncatingRemainder(dividingBy: 1)
                    let particle = project(V3(x + (side * 15 - x) * progress, y, 0))
                    particleDot(at: particle, color: color, radius: 2.7, context: &context)
                }
            }
        }
        plate(x: 0, width: 14, height: 80, depth: 24, color: Self.separatorColor, index: 1, context: &context)
        drawText("TANKS + REACTION STACK", at: CGPoint(x: center.x, y: Double(center.y) + 85 * scale), color: .white.opacity(0.42), size: 8, context: &context)
    }

    private func shellFill(_ shell: Path, context: inout GraphicsContext) {
        context.fill(shell, with: .linearGradient(Gradient(colors: [.white.opacity(solid ? 0.13 : 0.04), accent.opacity(0.015), .white.opacity(solid ? 0.1 : 0.025)]), startPoint: CGPoint(x: Double(center.x) - 70 * scale, y: Double(center.y) - 75 * scale), endPoint: CGPoint(x: Double(center.x) + 70 * scale, y: Double(center.y) + 75 * scale)))
        stroke(shell, color: accent, width: 1.1, opacity: 0.6, context: &context)
    }

    private func drawElectronCircuit(in context: inout GraphicsContext) {
        let waypoints = [V3(-37, -69, -34), V3(-89, -82, -34), V3(-89, -103, -34), V3(89, -103, -34), V3(89, -82, -34), V3(37, -69, -34)]
        let circuit = path(waypoints, close: false)
        context.stroke(circuit, with: .color(accent.opacity(working ? 0.34 : 0.15)), style: StrokeStyle(lineWidth: 0.9 * scale, lineCap: .round, dash: [3 * scale, 4 * scale]))
        let resistor = path([V3(-12, -106, -34), V3(-12, -100, -34), V3(12, -100, -34), V3(12, -106, -34)])
        context.fill(resistor, with: .color(accent.opacity(0.12)))
        stroke(resistor, color: accent, opacity: 0.6, context: &context)
        if working {
            for index in 0..<5 {
                let progress = (kineticTime * 0.28 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                let adjusted = current < 0 ? 1 - progress : progress
                let point = pointAlong(waypoints, fraction: moving ? adjusted : Double(index) / 5)
                particleDot(at: project(point), color: .white, radius: 1.9, context: &context)
            }
        }
        drawText(current < 0 ? "e⁻  ←  CHARGER" : "e⁻  →  LOAD", at: CGPoint(x: center.x, y: Double(center.y) - 118 * scale), color: accent.opacity(0.84), size: 8, context: &context)
    }

    private func drawIonTransport(in context: inout GraphicsContext) {
        let left = exploded ? -73.0 : -47.0
        let right = exploded ? 73.0 : 47.0
        for row in 0..<3 {
            let yy = -22 + Double(row) * 23
            let route = path([V3(left, yy, -38), V3(right, yy, -38)], close: false)
            context.stroke(route, with: .color(Self.separatorColor.opacity(working ? 0.21 : 0.08)), style: StrokeStyle(lineWidth: 0.7 * scale, dash: [2, 6]))
            if working {
                for index in 0..<4 {
                    let progress = (kineticTime * 0.22 + Double(index) / 4 + Double(row) * 0.09).truncatingRemainder(dividingBy: 1)
                    let adjusted = direction < 0 ? 1 - progress : progress
                    let localMotion = Double(index) / 4 + (moving ? sin(kineticTime * 1.8 + Double(index + row)) * 0.028 : 0)
                    let travel = carrierDirection == 0 ? localMotion : moving ? adjusted : Double(index) / 4
                    let point = project(V3(left + (right - left) * travel, yy, -38))
                    let color = travel < 0.5 ? Self.anodeColor : Self.cathodeColor
                    particleDot(at: point, color: color, radius: 2.8, context: &context)
                }
            }
        }
        // Ions cross the separator. Electrons take the independent external circuit above.
        let arrowY = 59.0
        let arrowX = direction * 12
        if carrierDirection != 0 {
            stroke(path([V3(-direction * 12, arrowY, -39), V3(direction * 12, arrowY, -39)], close: false), color: Self.separatorColor, opacity: working ? 0.8 : 0.25, context: &context)
            stroke(path([V3(arrowX - direction * 5, arrowY - 3, -39), V3(arrowX, arrowY, -39), V3(arrowX - direction * 5, arrowY + 3, -39)], close: false), color: Self.separatorColor, opacity: working ? 0.8 : 0.25, context: &context)
        }
        drawText(carrierLabel.uppercased(), at: project(V3(0, 74, -39)), color: Self.separatorColor.opacity(highContrast ? 0.9 : 0.6), size: 7, context: &context)
    }

    private func drawLight(in context: inout GraphicsContext) {
        let xx = lightX * 49
        let yy = lightY * 40
        let main = path([V3(xx - 32, -72 + yy, -45), V3(xx + 16, 72 + yy, -45)], close: false)
        context.stroke(main, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.22), .white.opacity(0.62), .clear]), startPoint: project(V3(xx - 32, -72 + yy, -45)), endPoint: project(V3(xx + 16, 72 + yy, -45))), lineWidth: 1.5 * scale)
        let chromatic = path([V3(xx - 35, -72 + yy, -45), V3(xx + 13, 72 + yy, -45)], close: false)
        context.stroke(chromatic, with: .linearGradient(Gradient(colors: [.clear, Self.anodeColor.opacity(0.4), Self.cathodeColor.opacity(0.22), .clear]), startPoint: project(V3(xx - 35, -72 + yy, -45)), endPoint: project(V3(xx + 13, 72 + yy, -45))), lineWidth: 0.8 * scale)
        if temperature > 40 {
            let heat = min(0.3, (temperature - 40) / 100)
            let rect = CGRect(x: Double(center.x) - 72 * scale, y: Double(center.y) - 84 * scale, width: 144 * scale, height: 168 * scale)
            context.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.orange.opacity(heat), .clear]), center: center, startRadius: 0, endRadius: 90 * scale))
        }
    }

    private func drawLabels(in context: inout GraphicsContext) {
        let yy = Double(center.y) + 99 * scale
        let leftX = Double(center.x) - 61 * scale
        let rightX = Double(center.x) + 61 * scale
        drawText("ANODE", at: CGPoint(x: leftX, y: yy), color: Self.anodeColor.opacity(0.9), size: 8, context: &context)
        drawText("CATHODE", at: CGPoint(x: rightX, y: yy), color: Self.cathodeColor.opacity(0.9), size: 8, context: &context)
        for side in [-1.0, 1.0] {
            var leader = Path()
            leader.move(to: CGPoint(x: Double(center.x) + side * 40 * scale, y: Double(center.y) + 72 * scale))
            leader.addLine(to: CGPoint(x: Double(center.x) + side * 61 * scale, y: yy - 8 * scale))
            context.stroke(leader, with: .color((side < 0 ? Self.anodeColor : Self.cathodeColor).opacity(0.3)), lineWidth: 0.6)
        }
    }

    private func drawText(_ text: String, at point: CGPoint, color: Color, size: Double, context: inout GraphicsContext) {
        context.draw(Text(text).font(.system(size: size * scale, weight: .medium, design: .monospaced)).foregroundColor(color), at: point)
    }

    private func particleDot(at point: CGPoint, color: Color, radius: Double, context: inout GraphicsContext) {
        let r = radius * scale
        let glow = CGRect(x: point.x - r * 2.4, y: point.y - r * 2.4, width: r * 4.8, height: r * 4.8)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [color.opacity(0.44), .clear]), center: point, startRadius: r * 0.3, endRadius: r * 2.4))
        context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.93)))
    }

    private func pointAlong(_ points: [V3], fraction: Double) -> V3 {
        let lengths = zip(points, points.dropFirst()).map { lhs, rhs in
            sqrt(pow(rhs.x - lhs.x, 2) + pow(rhs.y - lhs.y, 2) + pow(rhs.z - lhs.z, 2))
        }
        var remaining = lengths.reduce(0, +) * max(0, min(1, fraction))
        for index in lengths.indices {
            if remaining <= lengths[index] {
                let t = remaining / max(0.0001, lengths[index])
                let a = points[index]
                let b = points[index + 1]
                return V3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
            }
            remaining -= lengths[index]
        }
        return points.last ?? V3(0, 0, 0)
    }
}

private struct V3 {
    let x: Double
    let y: Double
    let z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
}
