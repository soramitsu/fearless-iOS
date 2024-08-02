import UIKit
import SoraUI

protocol SkeletonLoadableView: UIView {
    var container: UIView { get }
    var skeletonSize: CGSize { get set }
    var skeletonView: SkrullableView? { get set }

    func startSkeletonAnimation()
    func stopSkeletonAnimation()
    func updateSkeletonLayout()
}

extension SkeletonLoadableView {
    func startSkeletonAnimation() {
        guard skeletonView == nil else {
            return
        }
        let skeletonView = Skrull(
            size: skeletonSize,
            decorations: [],
            skeletons: [
                SingleSkeleton.createRow(position: CGPoint(x: 0, y: 0))
            ]
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: CGPoint(x: -skeletonSize.width, y: skeletonSize.height / 2), size: skeletonSize)
        skeletonView.autoresizingMask = []
        container.addSubview(skeletonView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    func stopSkeletonAnimation() {
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
    }

    func updateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        skeletonView.frame = CGRect(origin: CGPoint(x: -skeletonSize.width / 2, y: skeletonSize.height / 2), size: skeletonSize)
    }
}
