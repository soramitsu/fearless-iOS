//
//  Tabbar.swift
//  SoraSwiftUI
//
//  Created by Ivan Shlyapkin on 27.09.2022.
//

import UIKit

public class TabBar: UITabBar {

    public var didTapButton: (() -> ())?

    public lazy var middleButton: ImageButton = {
        let middleButton = ImageButton(size: CGSize(width: 56, height: 56))
        middleButton.sora.cornerRadius = .circle
        middleButton.sora.backgroundColor = .additionalPolkaswap
        middleButton.addTarget(self, action: #selector(didTapButton1), for: .touchUpInside)

        self.addSubview(middleButton)

        return middleButton
    }()

    @objc
    func didTapButton1() {
        didTapButton?()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(middleButton)

        NSLayoutConstraint.activate([
            middleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            middleButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -21)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var shapeLayer: CALayer?

    private func addShape() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = createPath()
        shapeLayer.strokeColor = UIColor.clear.cgColor
        shapeLayer.fillColor = Colors.white100.cgColor
        shapeLayer.lineWidth = 0

        if let oldShapeLayer = self.shapeLayer {
            self.layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
        } else {
            self.layer.insertSublayer(shapeLayer, at: 0)
        }

        self.shapeLayer = shapeLayer
    }

    public override func draw(_ rect: CGRect) {
        self.addShape()
    }

    func createPath() -> CGPath {

        let height: CGFloat = 32.0
        let path = UIBezierPath()
        let centerWidth = self.frame.width / 2

        path.move(to: CGPoint(x: 0, y: 0)) // start top left
        path.addLine(to: CGPoint(x: (centerWidth - height), y: 0)) // the beginning of the trough
        // first curve down
        path.addCurve(to: CGPoint(x: centerWidth, y: height),
                      controlPoint1: CGPoint(x: (centerWidth - height), y: 0), controlPoint2: CGPoint(x: centerWidth - height, y: height))
        // second curve up
        path.addCurve(to: CGPoint(x: (centerWidth + height), y: 0),
                      controlPoint1: CGPoint(x: centerWidth + height, y: height), controlPoint2: CGPoint(x: (centerWidth + height), y: 0))

        // complete the rect
        path.addLine(to: CGPoint(x: self.frame.width, y: 0))
        path.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.height))
        path.close()

        return path.cgPath
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !clipsToBounds && !isHidden && alpha > 0 else { return nil }
        for member in subviews.reversed() {
            let subPoint = member.convert(point, from: self)
            guard let result = member.hitTest(subPoint, with: event) else { continue }
            return result
        }
        return nil
    }
}

extension CGFloat {
    var degreesToRadians: CGFloat { return self * .pi / 180 }
    var radiansToDegrees: CGFloat { return self * 180 / .pi }
}
