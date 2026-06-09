/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

open class CharacterFieldsView: BaseCharacterFieldsView {

    open var fieldColor: UIColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }

    open var fieldFont: UIFont = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize) {
        didSet { setNeedsDisplay() }
    }

    open var fieldStrokeWidth: CGFloat = 1.0 {
        didSet {
            invalidateLayout()
            setNeedsDisplay()
        }
    }

    // MARK: Initialize

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    // MARK: Drawing
    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        drawFieldsBoundaries(rect)
        drawCharacters(rect)
    }

    private func drawCharacters(_ rect: CGRect) {
        let contentSize = self.intrinsicContentSize
        let originX = CGFloat(rect.origin.x + rect.size.width / 2.0 - contentSize.width / 2.0)
        let originY = CGFloat(rect.origin.y + rect.size.height / 2.0 - contentSize.height / 2.0)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: fieldColor,
            .font: fieldFont
        ]

        for index in 0..<characters.count {
            let text = String(characters[index])
            let textSize = text.size(withAttributes: textAttributes)

            let xCenter = CGFloat(index) * (fieldSize.width + fieldSpacing) + fieldSize.width / 2.0
            let xPos = originX + xCenter - textSize.width / 2.0
            let yPos = originY

            text.draw(in: CGRect(origin: CGPoint(x: xPos, y: yPos), size: fieldSize), withAttributes: textAttributes)
        }
    }

    private func drawFieldsBoundaries(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let contentSize = self.intrinsicContentSize
            let originX = CGFloat(rect.origin.x + rect.size.width / 2.0 - contentSize.width / 2.0)
            let originY = CGFloat(rect.origin.y + rect.size.height / 2.0 - contentSize.height / 2.0)

            UIGraphicsPushContext(context)

            context.setLineWidth(fieldStrokeWidth)
            context.setStrokeColor(fieldColor.cgColor)

            for index in 0..<numberOfCharacters {
                let xPos = originX + CGFloat(index) * (fieldSize.width + fieldSpacing)
                let yPos = originY + fieldSize.height - fieldStrokeWidth / 2.0

                context.move(to: CGPoint(x: xPos, y: yPos))
                context.addLine(to: CGPoint(x: xPos + fieldSize.width, y: yPos))
            }

            context.strokePath()

            UIGraphicsPopContext()
        }
    }
}
