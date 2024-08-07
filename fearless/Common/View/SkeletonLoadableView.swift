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
        guard skeletonView == nil, frame.origin != .zero else {
            return
        }

        let skeletonView = Skrull(
            size: skeletonSize,
            decorations: [],
            skeletons: [
                SingleSkeleton.createRow(spaceSize: .zero, position: CGPoint(x: 0.5, y: 0.5), size: skeletonSize)
            ]
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(
            origin: CGPoint(x: frame.size.width - skeletonSize.width, y: frame.size.height / 2 - skeletonSize.height / 2),
            size: CGSize(width: skeletonSize.width, height: skeletonSize.height)
        )
        skeletonView.autoresizingMask = []
        container.addSubview(skeletonView)

        skeletonView.startSkrulling()
        self.skeletonView = skeletonView
    }

    func stopSkeletonAnimation() {
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
    }

    func updateSkeletonLayout() {
        guard skeletonView != nil else {
            return
        }
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        startSkeletonAnimation()
    }
}
