import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

final class SkrullView: UIView {
    private struct Constants {
        static let gradientStartPoint: CGPoint = CGPoint(x: 0.0, y: 0.5)
        static let gradientEndPoint: CGPoint = CGPoint(x: 1.0, y: 0.5)
        static let animationStartPositions: [NSNumber] = [-1.0, -0.55, -0.45, 0.0]
        static let animationEndPositions: [NSNumber] = [1.0, 1.45, 1.55, 2.0]
        static let animationDuration: TimeInterval = 1.0
    }

    private(set) var decorations: [Decoration]
    private(set) var skeletons: [Skeleton]

    private let skeletonAnimator: SkeletonAnimatorProtocol = {
        return LocationSkeletonAnimator(startLocations: Constants.animationStartPositions,
                                        endLocations: Constants.animationEndPositions,
                                        duration: Constants.animationDuration)
    }()

    private var layers: [CAGradientLayer] = []

    private var fillSkeletonStartColor: UIColor
    private var fillSkeletonEndColor: UIColor

    private var isAnimating: Bool = false

    init(
        size: CGSize,
        decorations: [Decoration],
        skeletons: [Skeleton],
        fillSkeletonStartColor: UIColor?,
        fillSkeletonEndColor: UIColor?
    ) {
        self.decorations = decorations
        self.skeletons = skeletons
        self.fillSkeletonStartColor = fillSkeletonStartColor ?? UIColor.lightGray
        self.fillSkeletonEndColor = fillSkeletonEndColor ?? UIColor.gray

        super.init(frame: CGRect(origin: .zero, size: size))

        configure()
    }

    func update(size: CGSize, decorations: [Decoration], skeletons: [Skeleton]) {
        self.decorations = decorations

        frame = CGRect(origin: .zero, size: size)

        let oldCount = self.skeletons.count
        let newCount = skeletons.count

        self.skeletons = skeletons

        if oldCount > newCount {
            let layersToRemove = layers.suffix(oldCount - newCount)

            for layer in layersToRemove {
                layer.removeFromSuperlayer()
            }

            self.layers = Array(layers.prefix(newCount))
        }

        let maybeNewLayers: [CAGradientLayer]?

        if oldCount < newCount {
            let newSkeletons = Array(skeletons.suffix(newCount - oldCount))
            maybeNewLayers = configureLayers(for: newSkeletons)
        } else {
            maybeNewLayers = nil
        }

        for (index, layer) in layers.enumerated() {
            configurePosition(for: layer, skeleton: skeletons[index])
            configureLayerStyle(for: layer, skeleton: skeletons[index])
        }

        if let newLayers = maybeNewLayers, isAnimating {
            newLayers.forEach { skeletonAnimator.startAnimation(on: $0)}
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        configureLayers(for: skeletons)
    }

    @discardableResult
    private func configureLayers(for skeletons: [Skeleton]) -> [CAGradientLayer] {
        skeletons.forEach { skeleton in
            let skeletonLayer = createLayer(for: skeleton)
            layer.addSublayer(skeletonLayer)
            layers.append(skeletonLayer)
        }

        return Array(layers.suffix(skeletons.count))
    }

    private func createLayer(for skeleton: Skeleton) -> CAGradientLayer {
        let skeletonLayer = CAGradientLayer()

        configurePosition(for: skeletonLayer, skeleton: skeleton)
        configureLayerStyle(for: skeletonLayer, skeleton: skeleton)

        return skeletonLayer
    }

    // MARK: Layers

    override func layoutSubviews() {
        super.layoutSubviews()

        for (index, layer) in layers.enumerated() {
            configurePosition(for: layer, skeleton: skeletons[index])
        }
    }

    private func configurePosition(for layer: CALayer, skeleton: Skeleton) {
        let size = CGSize(width: skeleton.size.width * bounds.size.width,
                          height: skeleton.size.height * bounds.size.height)

        let position = CGPoint(x: bounds.origin.x + skeleton.position.x * bounds.size.width - size.width / 2.0,
                               y: bounds.origin.y + skeleton.position.y * bounds.size.height - size.height / 2.0)

        layer.frame = CGRect(origin: position, size: size)

        if let cornerRadii = skeleton.cornerRadii {
            let mode = skeleton.cornerRoundingMode ?? .allCorners

            let adjustedCornerRadii = CGSize(width: cornerRadii.width * size.width,
                                             height: cornerRadii.height * size.height)

            let path = UIBezierPath(roundedRect: layer.bounds,
                                    byRoundingCorners: mode,
                                    cornerRadii: adjustedCornerRadii)
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath

            layer.mask = shapeLayer
        }
    }

    private func configureLayerStyle(for layer: CAGradientLayer, skeleton: Skeleton) {
        let startColor = skeleton.startColor?.cgColor ?? fillSkeletonStartColor.cgColor
        let endColor = skeleton.endColor?.cgColor ?? fillSkeletonEndColor.cgColor

        layer.startPoint = Constants.gradientStartPoint
        layer.endPoint = Constants.gradientEndPoint
        layer.colors = [startColor, endColor, startColor]
        layer.locations = Constants.animationStartPositions
    }

    // MARK: Drawing decorations

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        decorations.forEach { draw(decoration: $0, context: context, rect: rect) }
    }

    private func draw(decoration: Decoration, context: CGContext, rect: CGRect) {
        let size = CGSize(width: decoration.size.width * rect.size.width,
                          height: decoration.size.height * rect.size.height)

        let frame = CGRect(x: rect.origin.x + decoration.position.x * rect.size.width - size.width / 2.0,
                           y: rect.origin.y + decoration.position.y * rect.size.height - size.height / 2.0,
                           width: size.width,
                           height: size.height)

        let bezierPath: UIBezierPath

        if let cornerRadii = decoration.cornerRadii {
            let cornerRadii = CGSize(width: cornerRadii.width * size.width, height: cornerRadii.height * size.height)
            bezierPath = UIBezierPath(roundedRect: frame,
                                      byRoundingCorners: decoration.cornerRoundingMode ?? .allCorners,
                                      cornerRadii: cornerRadii)
        } else {
            bezierPath = UIBezierPath(rect: frame)
        }

        context.saveGState()

        context.addPath(bezierPath.cgPath)

        if let fillColor = decoration.fillColor {
            context.setFillColor(fillColor.cgColor)
        }

        if let shadowOffset = decoration.shadowOffset {
            let shadowRadius = decoration.shadowRadius ?? 0.0
            context.setShadow(offset: shadowOffset, blur: shadowRadius, color: decoration.shadowColor?.cgColor)
        }

        if let strokeColor = decoration.strokeColor {
            context.setStrokeColor(strokeColor.cgColor)
        }

        if let lineWidth = decoration.strokeWidth {
            context.setLineWidth(lineWidth)
        }

        if decoration.shouldFill, decoration.shouldStroke {
            context.drawPath(using: .fillStroke)
        } else if decoration.shouldStroke {
            context.drawPath(using: .stroke)
        } else {
            context.drawPath(using: .fill)
        }

        context.restoreGState()
    }
}

extension SkrullView: Skrullable {
    func startSkrulling() {
        guard !isAnimating else {
            return
        }

        isAnimating = true

        layers.forEach { skeletonAnimator.startAnimation(on: $0) }
    }

    func stopSkrulling() {
        guard isAnimating else {
            return
        }

        isAnimating = false

        layers.forEach { skeletonAnimator.stopAnimation(on: $0) }
    }
}
