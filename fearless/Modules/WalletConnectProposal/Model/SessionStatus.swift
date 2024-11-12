import Foundation
import WalletConnectSign

enum SessionStatus {
    case proposal(ConnectProposal)
    case active(ActionConnect)

    var proposal: Session.Proposal? {
        switch self {
        case let .proposal(proposal):
            switch proposal {
            case let .walletConnect(proposal):
                return proposal
            case .tonJsBridge, .tonConnect:
                return nil
            }
        case .active:
            return nil
        }
    }

    var tonManifest: TonConnectManifest? {
        switch self {
        case let .proposal(proposal):
            switch proposal {
            case .walletConnect:
                return nil
            case let .tonJsBridge(manifest, _, _, _):
                return manifest
            case let .tonConnect(manifest, _):
                return manifest
            }
        case .active:
            return nil
        }
    }

    var session: Session? {
        switch self {
        case .proposal:
            return nil
        case let .active(session):
            switch session {
            case let .walletConnect(session):
                return session
            }
        }
    }

    var moduleOutput: WalletConnectProposalModuleOutput? {
        switch self {
        case let .proposal(proposal):
            switch proposal {
            case .walletConnect, .tonConnect:
                return nil
            case let .tonJsBridge(_, _, _, delegate):
                return delegate
            }
        case .active:
            return nil
        }
    }
}
