import Foundation
import WalletConnectSign

enum ConnectProposal {
    case walletConnect(Session.Proposal)
    case tonJsBridge(
        manifest: TonConnectManifest,
        requestPayload: TonConnectParameters,
        invocationId: String,
        delegate: (any WalletConnectProposalModuleOutput)?
    )
    case tonConnect(
        manifest: TonConnectManifest,
        requestPayload: TonConnectParameters
    )

    var walletConnectProposal: Session.Proposal? {
        switch self {
        case let .walletConnect(proposal): return proposal
        case .tonJsBridge, .tonConnect: return nil
        }
    }

    var tonConnectManifest: TonConnectManifest? {
        switch self {
        case .walletConnect, .tonConnect: return nil
        case let .tonJsBridge(manifest, _, _, _): return manifest
        }
    }
}

enum ActionConnect {
    case walletConnect(Session)
    case tonConnect(app: TonConnectApp, delegate: (any WalletConnectProposalModuleOutput)?)
}

final class WalletConnectProposalCoordinator: DefaultCoordinator, CoordinatorFinishOutput {
    private let router: WalletConnectCoordinatorRouter
    private let proposal: ConnectProposal

    init(
        router: WalletConnectCoordinatorRouter,
        proposal: ConnectProposal
    ) {
        self.router = router
        self.proposal = proposal
    }

    // MARK: - CoordinatorFinishOutput

    var finishFlow: (() -> Void)?

    // MARK: - Coordinator

    override func start() {
        runFlow()
    }

    // MARK: - Private methods

    private func runFlow() {
        let module: WalletConnectProposalModuleCreationResult?
        switch proposal {
        case let .walletConnect(proposal):
            module = WalletConnectProposalAssembly.configureModule(
                status: .proposal(.walletConnect(proposal))
            )
        case let .tonJsBridge(manifest, requestPayload, invocationId, delegate):
            module = WalletConnectProposalAssembly.configureModule(
                status: .proposal(.tonJsBridge(
                    manifest: manifest,
                    requestPayload: requestPayload,
                    invocationId: invocationId,
                    delegate: delegate
                ))
            )
        case let .tonConnect(manifest, requestPayload):
            module = WalletConnectProposalAssembly.configureModule(
                status: .proposal(.tonConnect(
                    manifest: manifest,
                    requestPayload: requestPayload
                ))
            )
        }
        guard let controller = module?.view.controller else {
            return
        }
        controller.addOnInteractionDismiss { [weak self] in
            self?.finishFlow?()
        }
        router.setRoot(controller: controller)
    }
}
