import UIKit
import Cosmos

class FWCosmosView: CosmosView {
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
