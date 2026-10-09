// Renders the app icon: swift scripts/make-icon.swift BudgetApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import SwiftUI
import AppKit

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

struct Icon: View {
    let green = Color(red: 0.16, green: 0.78, blue: 0.42)
    let teal = Color(red: 0.04, green: 0.70, blue: 0.68)
    let ringRadius: CGFloat = 375
    let endTrim: CGFloat = 0.80

    var body: some View {
        let theta = (-90 + Double(endTrim) * 360) * .pi / 180
        ZStack {
            LinearGradient(colors: [green, teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 520)

            // Rollover arrow circling the counter.
            Circle()
                .trim(from: 0.04, to: endTrim)
                .stroke(.white, style: StrokeStyle(lineWidth: 46, lineCap: .round))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .rotationEffect(.degrees(-90))
            Path { p in
                // Arrowhead continuing the arc clockwise: tip along the tangent, base across the stroke.
                let c = CGPoint(x: 512, y: 512)
                let e = CGPoint(x: c.x + ringRadius * cos(theta), y: c.y + ringRadius * sin(theta))
                let t = CGPoint(x: -sin(theta), y: cos(theta))
                let n = CGPoint(x: cos(theta), y: sin(theta))
                let len: CGFloat = 125, half: CGFloat = 70
                p.move(to: CGPoint(x: e.x + t.x * len, y: e.y + t.y * len))
                p.addLine(to: CGPoint(x: e.x + n.x * half - t.x * 8, y: e.y + n.y * half - t.y * 8))
                p.addLine(to: CGPoint(x: e.x - n.x * half - t.x * 8, y: e.y - n.y * half - t.y * 8))
                p.closeSubpath()
            }
            .fill(.white)
            .frame(width: 1024, height: 1024)

            // The big counter button.
            Circle()
                .fill(.white)
                .frame(width: 540, height: 540)
                .shadow(color: .black.opacity(0.18), radius: 30, y: 18)
            Text("$")
                .font(.system(size: 400, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [green, teal], startPoint: .top, endPoint: .bottom))
                .offset(y: -6)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render() {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    // App icons must be opaque (no alpha channel), so redraw into an RGB context.
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
MainActor.assumeIsolated { render() }
