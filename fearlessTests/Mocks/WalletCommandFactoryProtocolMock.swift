import Foundation
import UIKit
@testable import fearless

// Minimal shims for CommonWallet APIs used in tests
protocol WalletCommandProtocol { func execute() throws }
enum WalletPresentationStyle { case push(hidesBottomBar: Bool); case modal(inNavigation: Bool) }
protocol WalletPresentationCommandProtocol: WalletCommandProtocol { var presentationStyle: WalletPresentationStyle { get set }; var animated: Bool { get set }; var completionBlock: (() -> Void)? { get set } }
protocol AssetDetailsCommadProtocol: WalletPresentationCommandProtocol { var ignoredWhenSingleAsset: Bool { get set } }
enum WalletHideActionType { case dismiss, pop }
protocol WalletHideCommandProtocol: WalletCommandProtocol { var actionType: WalletHideActionType { get set }; var animated: Bool { get set }; var completionBlock: (() -> Void)? { get set } }
protocol WalletCommandFactoryProtocol {
    func prepareSendCommand(for assetId: String?) -> WalletPresentationCommandProtocol
    func prepareReceiveCommand(for assetId: String?) -> WalletPresentationCommandProtocol
    func prepareAssetDetailsCommand(for assetId: String) -> AssetDetailsCommadProtocol
    func prepareScanReceiverCommand() -> WalletPresentationCommandProtocol
    func prepareWithdrawCommand(for assetId: String, optionId: String) -> WalletPresentationCommandProtocol
    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommandProtocol
    func prepareHideCommand(with actionType: WalletHideActionType) -> WalletHideCommandProtocol
    func prepareAccountUpdateCommand() -> WalletCommandProtocol
    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol
    func prepareTransactionDetailsCommand(with transaction: AssetTransactionData) -> WalletPresentationCommandProtocol
    func prepareTransfer(with payload: TransferPayload) -> WalletPresentationCommandProtocol
}
struct TransferPayload {}

class WalletCommandProtocolMock: WalletCommandProtocol {
    func execute() throws {}
}

class WalletPresentationCommandProtocolMock: WalletCommandProtocolMock, WalletPresentationCommandProtocol {
    var presentationStyle: WalletPresentationStyle = .push(hidesBottomBar: true)
    var animated: Bool = false
    var completionBlock: (() -> Void)?
}

class AssetDetailsCommandProtocolMock: WalletPresentationCommandProtocolMock, AssetDetailsCommadProtocol {
    var ignoredWhenSingleAsset: Bool = false
}

class WalletHideCommandProtocolMock: WalletCommandProtocolMock, WalletHideCommandProtocol {
    var actionType: WalletHideActionType = .dismiss
    var animated: Bool = false
    var completionBlock: (() -> Void)?
}

final class WalletCommandFactoryProtocolMock: WalletCommandFactoryProtocol {
    var sendClosure: ((String?) -> WalletPresentationCommandProtocol)?
    var receiverClosure: ((String?) -> WalletPresentationCommandProtocol)?
    var assetDetailsClosure: ((String) -> AssetDetailsCommadProtocol)?
    var scanReceiverClosure: (() -> WalletPresentationCommandProtocol)?
    var withdrawClosure: ((String, String) -> WalletPresentationCommandProtocol)?
    var presentationClosure: ((UIViewController) -> WalletPresentationCommandProtocol)?
    var hideClosure: ((WalletHideActionType) -> WalletHideCommandProtocol)?
    var accountUpdateClosure: (() -> WalletCommandProtocol)?
    var languageUpdateClosure: ((WalletLanguage) -> WalletCommandProtocol)?
    var transactionClosure: ((AssetTransactionData) -> WalletPresentationCommandProtocol)?
    var transferClosure: ((TransferPayload) -> WalletPresentationCommandProtocol)?

    func prepareSendCommand(for assetId: String?) -> WalletPresentationCommandProtocol {
        if let closure = sendClosure {
            return closure(assetId)
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func prepareReceiveCommand(for assetId: String?) -> WalletPresentationCommandProtocol {
        if let closure = receiverClosure {
            return closure(assetId)
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func prepareAssetDetailsCommand(for assetId: String) -> AssetDetailsCommadProtocol {
        if let closure = assetDetailsClosure {
            return closure(assetId)
        } else {
            return AssetDetailsCommandProtocolMock()
        }
    }

    func prepareScanReceiverCommand() -> WalletPresentationCommandProtocol {
        if let closure = scanReceiverClosure {
            return closure()
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func prepareWithdrawCommand(for assetId: String, optionId: String)
        -> WalletPresentationCommandProtocol {
        if let closure = withdrawClosure {
            return closure(assetId, optionId)
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func preparePresentationCommand(for controller: UIViewController)
        -> WalletPresentationCommandProtocol {
        if let closure = presentationClosure {
            return closure(controller)
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func prepareHideCommand(with actionType: WalletHideActionType) -> WalletHideCommandProtocol {
        if let closure = hideClosure {
            return closure(actionType)
        } else {
            return WalletHideCommandProtocolMock()
        }
    }

    func prepareAccountUpdateCommand() -> WalletCommandProtocol {
        if let closure = accountUpdateClosure {
            return closure()
        } else {
            return WalletCommandProtocolMock()
        }
    }

    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol {
        if let closure = languageUpdateClosure {
            return closure(newLanguage)
        } else {
            return WalletCommandProtocolMock()
        }
    }

    func prepareTransactionDetailsCommand(with transaction: AssetTransactionData) -> WalletPresentationCommandProtocol {
        if let closure = transactionClosure {
            return closure(transaction)
        } else {
            return WalletPresentationCommandProtocolMock()
        }
    }

    func prepareTransfer(with payload: TransferPayload) -> WalletPresentationCommandProtocol {
        if let closure = transferClosure {
            return closure(payload)
        } else {
             return WalletPresentationCommandProtocolMock()
        }
    }
}
