import SoraUI
import UIKit

/// A screen that shows a transfer's seal (SPEC v4 part 3) over its full-page loader. The presenter tells it only what
/// it knows: the final press was authorised (`ready`), the network accepted the transfer, or it definitely failed.
protocol FWTransferSealShowing: AnyObject {
    func didReachTransferStage(_ stage: FWSealStage)
    func didBreakTransfer()
}

/// The seal takes the full-page loader's place (176 pt). It lives inside the loader view, so it leaves exactly when
/// the app's loader does: it never delays the result. A failure moves it out to break on its own.
enum FWTransferSeal {
    static let side: CGFloat = 176
    static let identifier = "FWTransferSeal"

    /// The app's loader in `container`, while it is showing or fading out.
    static func loadingView(in container: UIView) -> LoadingView? {
        let loaders = container.subviews.compactMap { $0 as? LoadingView }
        return loaders.first { $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier }
            ?? loaders.last
    }

    static func sealView(in container: UIView) -> FWSolarGeometryView? {
        for candidate in [container] + container.subviews {
            if let seal = candidate.subviews.first(where: { $0.accessibilityIdentifier == identifier }) as? FWSolarGeometryView {
                return seal
            }
        }
        return nil
    }

    static func reach(_ stage: FWSealStage, in container: UIView) {
        if let seal = sealView(in: container) {
            seal.advanceSeal(to: stage)
            return
        }
        guard stage == .ready, let loader = loadingView(in: container) else { return }
        FWSealRecord.shared.begin()
        loader.subviews.forEach { $0.isHidden = true }
        let seal = FWSolarGeometryView()
        seal.accessibilityIdentifier = identifier
        seal.radiusFraction = 0.85
        seal.recordsSealStages = true
        seal.frame = CGRect(x: 0, y: 0, width: side, height: side)
        seal.center = CGPoint(x: loader.bounds.midX, y: loader.bounds.midY)
        seal.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loader.addSubview(seal)
        seal.layoutIfNeeded()
        seal.showSeal(stage: .idle)
        seal.advanceSeal(to: .ready)
    }

    /// The transfer definitely failed: the figure turns ember and falls apart while the app shows its error.
    static func breakSeal(in container: UIView) {
        guard let seal = sealView(in: container) else { return }
        let frame = seal.superview?.convert(seal.frame, to: container) ?? seal.frame
        container.addSubview(seal)
        seal.frame = frame
        seal.isUserInteractionEnabled = false
        FWSealRecord.shared.reset()
        seal.breakSeal { [weak seal] in seal?.removeFromSuperview() }
    }
}

extension FearlessLoadingViewFactory {
    /// The app's own full-page loader carries the mirror loader (SPEC v4 part 4) in place of the spinning icon.
    static func addMirrorLoader(to loadingView: LoadingView) {
        let mirror = FWMirrorLoaderView()
        let side = FWMirrorLoaderView.pageSide
        mirror.frame = CGRect(
            x: loadingView.bounds.midX - side / 2, y: loadingView.bounds.midY - side / 2, width: side, height: side
        )
        mirror.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loadingView.addSubview(mirror)
    }
}
