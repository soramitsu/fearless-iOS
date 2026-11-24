import SoraUI
import UIKit

/// A screen that shows a transfer's seal (SPEC v4 part 3). The presenter tells it only what it knows: the final press
/// was authorised (`ready`), the network accepted the transfer, or it definitely failed; and when its loading ended.
protocol FWTransferSealShowing: AnyObject {
    func didReachTransferStage(_ stage: FWSealStage)
    func didBreakTransfer()
    /// The screen stopped its loading, whatever the outcome. A seal over the screen (not inside the app's loader,
    /// which leaves by itself) fades out now, without holding anything up.
    func didEndTransfer()
}

extension FWTransferSealShowing {
    func didEndTransfer() {}
}

/// The real events a confirm screen's presenter has, as the seal reads them.
enum FWTransferEvent: Equatable {
    /// The final press was authorised and the app starts preparing, signing and submitting.
    case authorised
    /// The network accepted the transfer: a hash came back.
    case accepted
    /// The transfer definitely failed or was rejected; the app shows its error.
    case definiteFailure
    /// The outcome is not known (the app shows its own recovery); the seal only fades.
    case outcomeUnknown

    /// What the seal draws for this event: a stage, a break, or nothing more.
    var stage: FWSealStage? {
        switch self {
        case .authorised: return .ready
        case .accepted: return .accepted
        case .definiteFailure, .outcomeUnknown: return nil
        }
    }

    var breaks: Bool { self == .definiteFailure }
}

/// Each flow's results as transfer events. Signed and sent are never reported: no confirm screen learns them apart
/// from the hash, so they draw together with acceptance.
enum FWTransferEvents {
    /// Cross-chain: included on the origin chain (awaiting the bridge) or accepted by the node (unconfirmed) both mean
    /// the network took it; any failure the presenter reports with its failure touch is definite.
    static func crossChain(_ result: Result<ReviewedCrossChainSubmissionResult, Error>) -> FWTransferEvent {
        switch result {
        case .success: return .accepted
        case .failure: return .definiteFailure
        }
    }

    /// Polkaswap swap, staking operations: a returned hash is acceptance; a failure is shown as the extrinsic failing.
    static func extrinsic(_ result: Result<String, Error>) -> FWTransferEvent {
        switch result {
        case .success: return .accepted
        case .failure: return .definiteFailure
        }
    }

    /// Payouts may come back as several hashes: acceptance once they all have; none is no acceptance.
    static func payouts(_ hashes: [String]) -> FWTransferEvent {
        hashes.isEmpty ? .outcomeUnknown : .accepted
    }

    /// Reports `event` to `view` if it shows a seal; a no-op otherwise. Synchronous and returns at once: the presenter
    /// goes on to show its result in the same turn.
    static func report(_ event: FWTransferEvent, to view: AnyObject?) {
        guard let view = view as? FWTransferSealShowing else { return }
        if let stage = event.stage {
            view.didReachTransferStage(stage)
        } else if event.breaks {
            view.didBreakTransfer()
        }
    }
}

/// Ink at 72 % over a screen whose loading is a spinner in its button, with the seal on it. It never takes a touch.
final class FWSealOverlayView: UIView {
    static let identifier = "FWTransferSealOverlay"
    static let inkAlpha: CGFloat = 0.72
    fileprivate(set) var isBreaking = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = Self.identifier
        backgroundColor = FWSunlit.Palette.background.withAlphaComponent(Self.inkAlpha)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// The seal takes the full-page loader's place (176 pt), inside the loader view, so it leaves exactly when the app's
/// loader does. Where a screen's loading is a spinner in its button, the seal shows above the screen on ink at 72 %
/// and fades when the loading ends. Either way it never delays the result. A failure breaks it beside the app's error.
enum FWTransferSeal {
    static let side: CGFloat = 176
    static let identifier = "FWTransferSeal"
    static let overlayFade: TimeInterval = 0.35

    /// The app's loader in `container`, while it is showing or fading out.
    static func loadingView(in container: UIView) -> LoadingView? {
        let loaders = container.subviews.compactMap { $0 as? LoadingView }
        return loaders.first { $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier }
            ?? loaders.last
    }

    static func overlay(in container: UIView) -> FWSealOverlayView? {
        container.subviews.compactMap { $0 as? FWSealOverlayView }.last
    }

    static func sealView(in container: UIView) -> FWSolarGeometryView? {
        for candidate in [container] + container.subviews {
            if let seal = candidate.subviews.first(where: { $0.accessibilityIdentifier == identifier }) as? FWSolarGeometryView {
                return seal
            }
        }
        return nil
    }

    private static var motionRestricted: Bool {
        FWMotionPolicy.current().isRestricted
    }

    /// `ready` puts the seal in the loader's place, or over the screen when there is no full-page loader (`overlay`).
    static func reach(_ stage: FWSealStage, in container: UIView, overlayWhenNoLoader: Bool = false) {
        if let seal = sealView(in: container) {
            seal.advanceSeal(to: stage)
            return
        }
        guard stage == .ready else { return }
        let host: UIView
        if let loader = loadingView(in: container) {
            loader.subviews.forEach { $0.isHidden = true }
            host = loader
        } else if overlayWhenNoLoader {
            let overlay = FWSealOverlayView(frame: container.bounds)
            container.addSubview(overlay)
            if !motionRestricted {
                overlay.alpha = 0
                UIView.animate(withDuration: FWShikiban.bundled.map { $0.durationsMs[2] / 1000 } ?? 0.18) {
                    overlay.alpha = 1
                }
            }
            host = overlay
        } else {
            return
        }
        FWSealRecord.shared.begin()
        let seal = FWSolarGeometryView()
        seal.accessibilityIdentifier = identifier
        seal.radiusFraction = 0.85
        seal.recordsSealStages = true
        seal.frame = CGRect(x: 0, y: 0, width: side, height: side)
        seal.center = CGPoint(x: host.bounds.midX, y: host.bounds.midY)
        seal.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        host.addSubview(seal)
        seal.layoutIfNeeded()
        seal.showSeal(stage: .idle)
        seal.advanceSeal(to: .ready)
    }

    /// The transfer definitely failed: the figure turns ember and falls apart while the app shows its error.
    static func breakSeal(in container: UIView) {
        guard let seal = sealView(in: container) else { return }
        FWSealRecord.shared.reset()
        if let overlay = overlay(in: container), seal.superview === overlay {
            overlay.isBreaking = true
            seal.breakSeal { [weak overlay] in remove(overlay) }
            return
        }
        let frame = seal.superview?.convert(seal.frame, to: container) ?? seal.frame
        container.addSubview(seal)
        seal.frame = frame
        seal.isUserInteractionEnabled = false
        seal.breakSeal { [weak seal] in seal?.removeFromSuperview() }
    }

    /// The screen's loading ended. An overlay seal fades out on the next turn, after the presenter has reported the
    /// outcome in this one (acceptance draws on as it fades; a break keeps it until the break is done). The loader's
    /// seal needs nothing: it leaves with the loader.
    static func end(in container: UIView) {
        guard let overlay = overlay(in: container) else { return }
        DispatchQueue.main.async { [weak overlay] in
            guard let overlay, overlay.superview != nil, !overlay.isBreaking else { return }
            remove(overlay)
        }
    }

    private static func remove(_ overlay: FWSealOverlayView?) {
        guard let overlay else { return }
        overlay.accessibilityIdentifier = nil
        guard !motionRestricted else {
            overlay.removeFromSuperview()
            return
        }
        UIView.animate(withDuration: overlayFade, animations: { overlay.alpha = 0 }, completion: { _ in
            overlay.removeFromSuperview()
        })
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
