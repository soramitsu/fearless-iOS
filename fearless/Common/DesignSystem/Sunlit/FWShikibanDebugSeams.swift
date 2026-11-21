import SoraFoundation
import SoraUI
import UIKit

#if DEBUG
    /// Debug-only seams for walking kit v4 on a simulator without real transfers or flaky networks:
    /// `xcrun simctl spawn <udid> notifyutil -p jp.co.soramitsu.fearless.debug.<name>` with
    /// - `seal`: a scripted transfer over the current screen (ready 0 s, signed 0.9 s, sent 1.7 s, accepted 2.9 s), then
    ///   the send success screen continuing the same figure;
    /// - `sealfail`: ready, signed, then a definite failure at 2.6 s (the seal breaks);
    /// - `dial` / `dialfail`: a synthetic sync of 14 networks through the wallet home's own tracker and dial over
    ///   3.2 s (`dialfail`: two give up);
    /// - `loader` / `loaderfill`: the app's full-page loader for 5 s (`loaderfill`: with a known amount filling);
    /// - `tick`: the wallet home's visible rows and total take a changed value through the value tick.
    /// None of this exists in release builds.
    enum FWShikibanDebugSeams {
        static let prefix = "jp.co.soramitsu.fearless.debug."
        static let names = [
            "seal", "sealfail", "dial", "dialfail", "loader", "loaderfill", "tick",
            "sealflow.swap", "sealflow.swapfail", "sealflow.crosschain", "sealflow.crosschainfail",
            "sealflow.staking", "sealflow.stakingfail"
        ]
        /// Posted on the default centre with `failures` (Int) for the wallet home's dial.
        static let syncNotification = Notification.Name("FWShikibanDebugSync")
        /// Posted on the default centre for the value tick.
        static let tickNotification = Notification.Name("FWShikibanDebugTick")
        private static var installed = false

        static func install() {
            guard !installed else { return }
            installed = true
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            for name in names {
                CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                    guard let name = name?.rawValue as String? else { return }
                    DispatchQueue.main.async { FWShikibanDebugSeams.handle(String(name.dropFirst(FWShikibanDebugSeams.prefix.count))) }
                }, (prefix + name) as CFString, nil, .deliverImmediately)
            }
        }

        private static var topController: UIViewController? {
            var top = SceneWindowFinder.mainWindow()?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }

        static func handle(_ name: String) {
            switch name {
            case "seal": runSeal(fails: false)
            case "sealfail": runSeal(fails: true)
            case "dial": NotificationCenter.default.post(name: syncNotification, object: nil, userInfo: ["failures": 0])
            case "dialfail": NotificationCenter.default.post(name: syncNotification, object: nil, userInfo: ["failures": 2])
            case "loader": runLoader(fill: false)
            case "loaderfill": runLoader(fill: true)
            case "tick": NotificationCenter.default.post(name: tickNotification, object: nil)
            case "sealflow.swap": FWSealFlowDebug.run(.swap, fails: false)
            case "sealflow.swapfail": FWSealFlowDebug.run(.swap, fails: true)
            case "sealflow.crosschain": FWSealFlowDebug.run(.crossChain, fails: false)
            case "sealflow.crosschainfail": FWSealFlowDebug.run(.crossChain, fails: true)
            case "sealflow.staking": FWSealFlowDebug.run(.staking, fails: false)
            case "sealflow.stakingfail": FWSealFlowDebug.run(.staking, fails: true)
            default: break
            }
        }

        private static func runLoader(fill: Bool) {
            guard let host = topController?.view else { return }
            let loader = FearlessLoadingViewFactory.createLoadingView()
            loader.frame = host.bounds
            loader.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.addSubview(loader)
            loader.startAnimating()
            let mirror = loader.subviews.compactMap { $0 as? FWMirrorLoaderView }.first
            if fill {
                for step in 0 ... 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.2) {
                        mirror?.progress = Double(step) / 20
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                loader.stopAnimating()
                loader.removeFromSuperview()
            }
        }

        /// The real seal path: a loader on the top screen, the seal in its place, stages as a transfer reports them.
        private static func runSeal(fails: Bool) {
            guard let top = topController, let host = top.view else { return }
            let loader = FearlessLoadingViewFactory.createLoadingView()
            loader.accessibilityIdentifier = LoadableViewProtocolConstants.activityIndicatorIdentifier
            loader.frame = host.bounds
            loader.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.addSubview(loader)
            loader.startAnimating()
            FWTransferSeal.reach(.ready, in: host)
            let script: [(TimeInterval, FWSealStage)] = [(0.9, .signed), (1.7, .sent)] + (fails ? [] : [(2.9, .accepted)])
            for (time, stage) in script {
                DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                    FWTransferSeal.reach(stage, in: host)
                }
            }
            let end: TimeInterval = fails ? 2.6 : 2.9
            DispatchQueue.main.asyncAfter(deadline: .now() + end) {
                loader.accessibilityIdentifier = nil
                if fails {
                    FWTransferSeal.breakSeal(in: host)
                }
                UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration) {
                    loader.alpha = 0
                } completion: { _ in
                    loader.stopAnimating()
                    loader.removeFromSuperview()
                }
                guard !fails, let controller = AllDoneAssembly.configureModule(
                    chainAsset: nil, hashString: "0x5f0d…debug", celebration: .send
                )?.view.controller else { return }
                controller.modalPresentationStyle = .custom
                controller.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
                    configuration: ModalSheetPresentationConfiguration.fearlessBlur
                )
                top.present(controller, animated: true)
            }
        }
    }

    /// `sealflow.<swap|crosschain|staking>[fail]`: the real confirm screen of the flow (empty of data: its presenter is
    /// a stub) presented over the current one, then the presenter's own sequence replayed against it: loading starts
    /// with `.authorised`, then 2.4 s later loading stops and the result is reported (a hash, or a definite failure),
    /// followed by what the flow's router shows: cross-chain's success screen with the ignite, swap's plain success
    /// screen, staking's "Transaction submitted" notice, or the app's "transaction failed" error.
    enum FWSealFlowDebug {
        enum Flow { case swap, crossChain, staking }

        final class Stub: PolkaswapSwapConfirmationViewOutput, CrossChainConfirmationViewOutput,
            StakingRebondConfirmationPresenterProtocol {
            func didLoad(view _: PolkaswapSwapConfirmationViewInput) {}
            func didTapBackButton() {}
            func didTapConfirmButton() {}
            func didLoad(view _: CrossChainConfirmationViewInput) {}
            func backButtonDidTapped() {}
            func confirmButtonTapped() {}
            func setup() {}
            func confirm() {}
            func selectAccount() {}
        }

        final class Router: BaseErrorPresentable, SheetAlertPresentable, ErrorPresentable, ModalAlertPresenting {}

        private static let stub = Stub()
        private static let router = Router()

        static func run(_ flow: Flow, fails: Bool) {
            guard let top = topController else { return }
            let screen: UIViewController & LoadableViewProtocol & ControllerBackedProtocol
            switch flow {
            case .swap:
                screen = PolkaswapSwapConfirmationViewController(output: stub, localizationManager: LocalizationManager.shared)
            case .crossChain:
                screen = CrossChainConfirmationViewController(output: stub, localizationManager: LocalizationManager.shared)
            case .staking:
                screen = StakingRebondConfirmationViewController(presenter: stub, localizationManager: LocalizationManager.shared)
            }
            let navigation = UINavigationController(rootViewController: screen)
            navigation.modalPresentationStyle = .fullScreen
            top.present(navigation, animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                screen.didStartLoading()
                FWTransferEvents.report(.authorised, to: screen)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                screen.didStopLoading()
                FWTransferEvents.report(fails ? .definiteFailure : .accepted, to: screen)
                if fails {
                    router.presentExtrinsicFailed(from: screen, locale: LocalizationManager.shared.selectedLocale)
                    return
                }
                switch flow {
                case .crossChain:
                    let done = AllDoneAssembly.configureModule(chainAsset: nil, hashString: "0x5f0d…debug", celebration: .send)?
                        .view.controller
                    navigation.dismiss(animated: true) {
                        guard let done else { return }
                        done.modalPresentationStyle = .custom
                        done.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
                            configuration: ModalSheetPresentationConfiguration.fearlessBlur
                        )
                        top.present(done, animated: true)
                    }
                case .swap:
                    guard let done = AllDoneAssembly.configureModule(chainAsset: nil, hashString: "0x5f0d…debug")?
                        .view.controller else { return }
                    done.modalPresentationStyle = .custom
                    done.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
                        configuration: ModalSheetPresentationConfiguration.fearlessBlur
                    )
                    screen.present(done, animated: true)
                case .staking:
                    let title = R.string.localizable.commonTransactionSubmitted(
                        preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                    )
                    navigation.dismiss(animated: true) {
                        router.presentSuccessNotification(title, from: top as? ControllerBackedProtocol, completion: nil)
                    }
                }
            }
        }

        private static var topController: UIViewController? {
            var top = SceneWindowFinder.mainWindow()?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }
    }
#endif
