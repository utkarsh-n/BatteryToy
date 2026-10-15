import AppKit
import Foundation

// Code-native artwork: a floating electrode pair within an energy orbit.
let output = CommandLine.arguments[1]
let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
let bounds = NSRect(x: 0, y: 0, width: side, height: side)
NSColor(calibratedRed: 0.018, green: 0.027, blue: 0.055, alpha: 1).setFill()
bounds.fill()
let cyan = NSColor(calibratedRed: 0.32, green: 0.94, blue: 0.96, alpha: 1)
let pink = NSColor(calibratedRed: 0.99, green: 0.43, blue: 0.79, alpha: 1)
for radius in stride(from: 390.0, through: 40.0, by: -5.0) {
    cyan.withAlphaComponent(0.004).setFill()
    NSBezierPath(ovalIn: NSRect(x: 512-radius, y: 512-radius, width: radius*2, height: radius*2)).fill()
}
let orbit = NSBezierPath()
orbit.appendArc(withCenter: NSPoint(x: 512, y: 520), radius: 333, startAngle: -48, endAngle: 229, clockwise: false)
orbit.lineWidth = 8
cyan.withAlphaComponent(0.85).setStroke(); orbit.stroke()
for index in 0...50 {
    let angle = (Double(index) / 50 * 277 - 48) * Double.pi / 180
    let start = 351.0
    let end = index % 5 == 0 ? 372.0 : 361.0
    let tick = NSBezierPath()
    tick.move(to: NSPoint(x: 512+cos(angle)*start, y: 520+sin(angle)*start))
    tick.line(to: NSPoint(x: 512+cos(angle)*end, y: 520+sin(angle)*end))
    tick.lineWidth = 2; NSColor.white.withAlphaComponent(index % 5 == 0 ? 0.4 : 0.18).setStroke(); tick.stroke()
}
func slab(x: Double, width: Double, color: NSColor) {
    let face = NSBezierPath(roundedRect: NSRect(x: x, y: 320, width: width, height: 388), xRadius: 16, yRadius: 16)
    NSGradient(starting: color.withAlphaComponent(0.6), ending: color.withAlphaComponent(0.08))!.draw(in: face, angle: -60)
    color.withAlphaComponent(0.93).setStroke(); face.lineWidth = 3; face.stroke()
    let edge = NSBezierPath()
    edge.move(to: NSPoint(x: x+width, y: 708)); edge.line(to: NSPoint(x: x+width+27, y: 735))
    edge.line(to: NSPoint(x: x+width+27, y: 347)); edge.line(to: NSPoint(x: x+width, y: 320))
    color.withAlphaComponent(0.45).setStroke(); edge.lineWidth = 2; edge.stroke()
    for row in 0..<9 {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x+15, y: 354+Double(row)*38))
        line.line(to: NSPoint(x: x+width-15, y: 354+Double(row)*38))
        color.withAlphaComponent(0.22).setStroke(); line.lineWidth = 2; line.stroke()
    }
}
slab(x: 326, width: 150, color: cyan)
slab(x: 506, width: 14, color: .white)
slab(x: 550, width: 150, color: pink)
for x in [359.0, 601.0] {
    let tab = NSBezierPath(roundedRect: NSRect(x: x, y: 715, width: 57, height: 43), xRadius: 8, yRadius: 8)
    NSColor.white.withAlphaComponent(0.25).setFill(); tab.fill()
    NSColor.white.withAlphaComponent(0.6).setStroke(); tab.lineWidth = 2; tab.stroke()
}
for index in 0..<7 {
    let x = 357.0 + Double(index)*47
    let y = 460.0 + sin(Double(index)*0.9)*27
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 10, height: 10)).fill()
}
let glint = NSBezierPath()
glint.move(to: NSPoint(x: 356, y: 700)); glint.line(to: NSPoint(x: 611, y: 326))
glint.lineWidth = 3; NSColor.white.withAlphaComponent(0.46).setStroke(); glint.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
