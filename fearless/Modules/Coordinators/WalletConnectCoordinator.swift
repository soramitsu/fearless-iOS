import Foundation
import SoraFoundation
import WalletConnectSign
import UIKit
import SSFNetwork
import SSFModels

final class WalletConnectCoordinator: DefaultCoordinator {
    static let shared = WalletConnectCoordinator()

    // MARK: - Private properties

    private let walletConnect: WalletConnectService = WalletConnectServiceImpl.shared
    private let tonConnect: TonConnectService = ServiceAssembly.shared.tonConnectService()

    private lazy var router: WalletConnectCoordinatorRouter = {
        WalletConnectCoordinatorRouterImpl()
    }()

    private lazy var applicationHandler: ApplicationHandler = {
        ApplicationHandler()
    }()

    override private init() {
        super.init()
        walletConnect.set(listener: self)
        Task { await tonConnect.set(listener: self) }
        applicationHandler.delegate = self
    }

    // MARK: - private methods

    private func presentNextIfPossible() {
        guard childCoordinators.isNotEmpty, let nextCoordinator = childCoordinators.first, !router.isBusy else {
            return
        }
        nextCoordinator.start()
    }

    private func startIfPossible(with coordinator: DefaultCoordinator) {
        let applicationState = UIApplication.shared.applicationState
        switch applicationState {
        case .active:
            addChildCoordinator(coordinator)
            guard !router.isBusy else {
                return
            }
            coordinator.start()

        case .background, .inactive:
            addChildCoordinator(coordinator)
        @unknown default:
            preconditionFailure()
        }
    }
}

// MARK: - WalletConnectServiceDelegate

extension WalletConnectCoordinator: WalletConnectServiceDelegate {
    func sign(request: Request, session: Session?) {
        let coordinator = WalletConnectSessionCoordinator(
            router: router,
            variant: .walletConnect(request: request, session: session)
        )
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
    }

    func session(proposal: Session.Proposal) {
        let coordinator = WalletConnectProposalCoordinator(
            router: router,
            proposal: .walletConnect(proposal)
        )
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        startIfPossible(with: coordinator)
    }
}

extension WalletConnectCoordinator: TonConnectServiceDelegate {
    func send(
        request: TonConnect.AppRequest,
        walletId: SSFModels.MetaAccountId,
        app: TonConnectApp
    ) {
        let coordinator = WalletConnectSessionCoordinator(
            router: router,
            variant: .tonConnect(
                request: request,
                walletId: walletId,
                app: app
            )
        )
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        Task { @MainActor in
            startIfPossible(with: coordinator)
        }
    }

    func send(
        request: TonConnect.AppRequest,
        invocationId: String,
        wallet: MetaAccountModel,
        dapp: TonDapp,
        delegate: (any WalletConnectSessionModuleOutput)?
    ) {
        let coordinator = WalletConnectSessionCoordinator(
            router: router,
            variant: .tonJsBridge(
                invocationId: invocationId,
                wallet: wallet,
                dapp: dapp,
                request: request,
                delegate: delegate
            )
        )
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        Task { @MainActor in
            startIfPossible(with: coordinator)
        }
    }

    func suggestConnect(
        manifest: TonConnectManifest,
        requestPayload: TonConnectParameters,
        invocationId: String?,
        delegate: (any WalletConnectProposalModuleOutput)?
    ) {
        let proposal: ConnectProposal
        if let invocationId, let delegate {
            proposal = .tonJsBridge(
                manifest: manifest,
                requestPayload: requestPayload,
                invocationId: invocationId,
                delegate: delegate
            )
        } else {
            proposal = .tonConnect(
                manifest: manifest,
                requestPayload: requestPayload
            )
        }
        let coordinator = WalletConnectProposalCoordinator(
            router: router,
            proposal: proposal
        )
        coordinator.finishFlow = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
            self?.router.dismiss { [weak self] in
                self?.presentNextIfPossible()
            }
        }
        Task { @MainActor in
            startIfPossible(with: coordinator)
        }
    }
}

// MARK: - ApplicationHandlerDelegate

extension WalletConnectCoordinator: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presentNextIfPossible()
    }
}
