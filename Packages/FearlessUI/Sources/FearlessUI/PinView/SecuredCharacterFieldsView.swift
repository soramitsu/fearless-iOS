/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

open class SecuredCharacterFieldsView: BaseCharacterFieldsView {
    open var fillColor: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }

    open var strokeColor: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }

    open var strokeWidth: CGFloat = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    open var fieldRadius: CGFloat = 10.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: Draw

    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        if let context = UIGraphicsGetCurrentContext() {
            let contentSize = self.intrinsicContentSize
            let originX = self.bounds.origin.x + self.bounds.size.width / 2.0 - contentSize.width / 2.0
            let originY = self.bounds.origin.y + self.bounds.size.height / 2.0 - fieldSize.height / 2.0

            context.setStrokeColor(strokeColor.cgColor)
            context.setFillColor(fillColor.cgColor)
            context.setLineWidth(strokeWidth)

            let yPos = originY + fieldSize.height / 2.0
            for index in 0..<numberOfCharacters {
                let xPos = originX + CGFloat(index) * (fieldSize.width + fieldSpacing) + fieldSize.width / 2.0

                context.addArc(center: CGPoint(x: xPos, y: yPos),
                               radius: fieldRadius,
                               startAngle: 0.0,
                               endAngle: CGFloat(2.0 * Double.pi),
                               clockwise: true)

                if index < characters.count {
                    context.fillPath()
                } else {
                    context.strokePath()
                }
            }
        }
    }
}
