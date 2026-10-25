import UIKit

public struct PolkadotIcon {
    public struct Circle: Equatable {
        public let origin: CGPoint
        public let color: UIColor
        public let radius: CGFloat

        public init(origin: CGPoint, color: UIColor, radius: CGFloat) {
            self.origin = origin
            self.color = color
            self.radius = radius
        }
    }

    public let circles: [Circle]
    public let radius: CGFloat

    public init(radius: CGFloat, circles: [Circle]) {
        self.radius = radius
        self.circles = circles
    }
}

extension PolkadotIcon: DrawableIcon {
    public func drawInContext(_ context: CGContext, fillColor: UIColor, size: CGSize) {
        let targetRadius = min(size.width, size.height) / 2.0

        let scale = targetRadius / radius
        let translation = CGPoint(x: size.width / 2.0, y: size.height / 2.0)

        let transformedCircles: [Circle] = circles.map { circle in
            let center = CGPoint(
                x: circle.origin.x * scale + translation.x,
                y: circle.origin.y * scale + translation.y
            )

            return Circle(
                origin: center,
                color: circle.color,
                radius: circle.radius * scale
            )
        }

        context.addArc(
            center: CGPoint(x: size.width / 2.0, y: size.height / 2.0),
            radius: targetRadius,
            startAngle: 0.0,
            endAngle: 2.0 * CGFloat.pi,
            clockwise: true
        )

        context.setFillColor(fillColor.cgColor)

        context.fillPath()

        for circle in transformedCircles {
            context.addArc(
                center: circle.origin,
                radius: circle.radius,
                startAngle: 0.0,
                endAngle: 2.0 * CGFloat.pi,
                clockwise: true
            )

            context.setFillColor(circle.color.cgColor)

            context.fillPath()
        }
    }
}
