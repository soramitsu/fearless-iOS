import UIKit
import Cosmos

class FWCosmosView: CosmosView {
    override var intrinsicContentSize: CGSize {
        let content = (layer.sublayers ?? []).reduce(CGRect.null) { $0.union($1.frame) }
        guard !content.isNull else { return super.intrinsicContentSize }
        return CGSize(width: content.maxX, height: content.maxY - min(0, content.minY))
    }

    override func update() {
        super.update()
        // Cosmos centers larger text around its star and excludes the negative
        // text origin from its intrinsic height. Keep the complete glyph layer
        // inside this view so a scrolling parent cannot clip it.
        let layers = layer.sublayers ?? []
        let top = layers.map { $0.frame.minY }.min() ?? 0
        if top < 0 {
            layers.forEach { $0.frame.origin.y -= top }
        }
        invalidateIntrinsicContentSize()
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let oprimizedBounds = FWCosmosTouchTarget.optimize(bounds)
        return oprimizedBounds.contains(point)
    }
}

enum FWCosmosTouchTarget {
    static func optimize(_ bounds: CGRect) -> CGRect {
        let recommendedHitSize: CGFloat = 44

        var hitWidthIncrease: CGFloat = recommendedHitSize - bounds.width
        var hitHeightIncrease: CGFloat = recommendedHitSize - bounds.height

        if hitWidthIncrease < 0 { hitWidthIncrease = 0 }
        if hitHeightIncrease < 0 { hitHeightIncrease = 0 }

        let extendedBounds: CGRect = bounds.insetBy(
            dx: -hitWidthIncrease / 2,
            dy: -hitHeightIncrease / 2
        )

        return extendedBounds
    }
}
