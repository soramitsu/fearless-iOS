import UIKit
import SSFUtils

public struct EthereumIcon {
    public struct Square: Equatable {
        public let origin: CGPoint
        public let color: UIColor
        public let sideSize: CGFloat
        public let rotation: CGFloat

        public init(origin: CGPoint, color: UIColor, sideSize: CGFloat, rotation: CGFloat) {
            self.origin = origin
            self.color = color
            self.sideSize = sideSize
            self.rotation = rotation
        }
    }

    public let squares: [Square]
    public let radius: CGFloat

    public init(radius: CGFloat, squares: [Square]) {
        self.radius = radius
        self.squares = squares
    }
}

extension EthereumIcon: DrawableIcon {
    public func drawInContext(_ context: CGContext, fillColor: UIColor, size: CGSize) {
        let targetRadius = min(size.width, size.height) / 2.0

        let scale = targetRadius / radius

        let shuffledSquares: [Square] = [squares[3], squares[1], squares[2], squares[0]]

        let transformedSquares: [Square] = shuffledSquares.map { square in
            let center = CGPoint(
                x: square.origin.x * scale,
                y: square.origin.y * scale
            )

            return Square(
                origin: center,
                color: square.color,
                sideSize: square.sideSize * scale,
                rotation: square.rotation
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

        context.strokePath()

        guard let squaresContext = UIGraphicsGetCurrentContext() else {
            return
        }

        if let mask = context.makeImage() {
            squaresContext.clip(to: CGRect(origin: .zero, size: size), mask: mask)

            for square in transformedSquares {
                squaresContext.addRect(
                    CGRect(
                        origin: square.origin,
                        size: CGSize(
                            width: square.sideSize,
                            height: square.sideSize
                        )
                    )
                )

                squaresContext.setFillColor(square.color.cgColor)

                squaresContext.fillPath()

                squaresContext.rotate(by: square.rotation)
            }
        }
    }
}
