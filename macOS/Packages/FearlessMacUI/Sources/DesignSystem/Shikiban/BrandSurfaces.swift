import SwiftUI

/// The asanoha (hemp leaf) lattice from the brand kit, tiled across a
/// surface. Drawn once and rasterised; it never animates.
public struct AsanohaPattern: View {
    private let cell: CGFloat
    private let color: Color
    private let lineWidth: CGFloat

    public init(cell: CGFloat = 26, color: Color = .white, lineWidth: CGFloat = 0.5) {
        self.cell = cell
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Canvas { context, size in
            let tileHeight = cell * ShikibanTokens.asanohaHeight
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    for line in ShikibanTokens.asanohaLines {
                        path.move(to: CGPoint(x: x + line.0 * cell, y: y + line.1 * cell))
                        path.addLine(to: CGPoint(x: x + line.2 * cell, y: y + line.3 * cell))
                    }
                    x += cell
                }
                y += tileHeight
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Gold corner brackets and edge ticks: the composition marks of a brand card.
public struct RegistrationMarks: View {
    private let inset: CGFloat
    private let arm: CGFloat

    public init(inset: CGFloat = 9, arm: CGFloat = 10) {
        self.inset = inset
        self.arm = arm
    }

    public var body: some View {
        Canvas { context, size in
            var brackets = Path()
            let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (inset, inset, 1, 1),
                (size.width - inset, inset, -1, 1),
                (inset, size.height - inset, 1, -1),
                (size.width - inset, size.height - inset, -1, -1)
            ]
            for corner in corners {
                brackets.move(to: CGPoint(x: corner.0 + arm * corner.2, y: corner.1))
                brackets.addLine(to: CGPoint(x: corner.0, y: corner.1))
                brackets.addLine(to: CGPoint(x: corner.0, y: corner.1 + arm * corner.3))
            }
            context.stroke(brackets, with: .color(BrandPalette.gold.opacity(0.7)), lineWidth: 1)

            var ticks = Path()
            let invRoot2 = 1 / CGFloat(2).squareRoot()
            for fraction in [1 - invRoot2, 0.5, invRoot2] {
                let x = size.width * fraction
                ticks.move(to: CGPoint(x: x, y: 4))
                ticks.addLine(to: CGPoint(x: x, y: 8))
                ticks.move(to: CGPoint(x: x, y: size.height - 8))
                ticks.addLine(to: CGPoint(x: x, y: size.height - 4))
            }
            context.stroke(ticks, with: .color(BrandPalette.gold.opacity(0.45)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The full-window brand surface behind the welcome and lock screens: ink
/// with the icon's sunrise glow from the top, the lattice at low strength
/// and two soft drifting glows. Nothing moves under Reduce Motion.
public struct BrandBackdrop: View {
    @MotionAllowed private var motionAllowed
    @State private var drift = false

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height)
            ZStack {
                BrandPalette.ink
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0xFF7A2E).opacity(0.50), location: 0),
                        .init(color: Color(hex: 0xE0126E).opacity(0.36), location: 0.22),
                        .init(color: Color(hex: 0x4A1160).opacity(0.55), location: 0.55),
                        .init(color: BrandPalette.ink.opacity(0), location: 1)
                    ],
                    center: UnitPoint(x: 0.5, y: -0.08),
                    startRadius: 0,
                    endRadius: side * 0.82
                )
                Circle()
                    .fill(BrandPalette.pink.opacity(0.16))
                    .frame(width: side * 0.55)
                    .blur(radius: side * 0.12)
                    .offset(x: drift ? side * 0.22 : -side * 0.2, y: side * 0.24)
                Circle()
                    .fill(BrandPalette.ember.opacity(0.11))
                    .frame(width: side * 0.45)
                    .blur(radius: side * 0.12)
                    .offset(x: drift ? -side * 0.26 : side * 0.24, y: -side * 0.1)
                AsanohaPattern(cell: 30, color: .white, lineWidth: 0.5)
                    .opacity(0.045)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            guard motionAllowed else { return }
            withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// A slowly turning ring of ticks with the solar rings, for brand moments.
public struct SolarHalo: View {
    private let size: CGFloat

    @MotionAllowed private var motionAllowed

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Group {
            if motionAllowed {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, canvasSize in
                        draw(in: &context, size: canvasSize, seconds: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            } else {
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize, seconds: 0)
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, seconds: Double) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) / 2 * 0.96
        for index in SolarGeometry.ringIndices {
            let stroke = SolarGeometry.strokes[index]
            let path = ShikibanGeometry.path(for: stroke, centre: centre, scale: scale)
            context.stroke(path, with: .color(BrandPalette.sealCore.opacity(0.55)), lineWidth: max(0.75, scale * SolarGeometry.coreWidth * stroke.weight))
        }
        // The hexagram at rest strength, so the mark sits on the kit's figure.
        for index in SolarGeometry.hexagramIndices {
            let path = ShikibanGeometry.path(for: SolarGeometry.strokes[index], centre: centre, scale: scale)
            context.stroke(path, with: .color(BrandPalette.sealCore.opacity(0.16)), lineWidth: 0.75)
        }
        let turns = seconds * SolarGeometry.tickTurnsPerSecond * 4
        var dots = Path()
        let radius = max(0.6, scale * SolarGeometry.tickSize)
        for tick in 0..<SolarGeometry.tickCount {
            let angle = 2 * Double.pi * (Double(tick) / Double(SolarGeometry.tickCount) + turns)
            let p = ShikibanGeometry.point(
                SolarGeometry.tickRadius * CGFloat(cos(angle)),
                SolarGeometry.tickRadius * CGFloat(sin(angle)),
                centre: centre,
                scale: scale
            )
            dots.addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
        }
        context.fill(dots, with: .color(BrandPalette.sealCore.opacity(0.8)))
    }
}
