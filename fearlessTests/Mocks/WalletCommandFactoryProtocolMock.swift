import Foundation
import CommonWallet

class WalletCommandProtocolMock: WalletCommandProtocol {
    func execute() throws {}
}

class WalletPresentationCommandProtocolMock: WalletCommandProtocolMock, WalletPresentationCommandProtocol {
    var presentationStyle: WalletPresentationStyle = .push(hidesBottomBar: true)
    var animated: Bool = false
}

class AssetDetailsCommandProtocolMock: WalletPresentationCommandProtocolMock, AssetDetailsCommadProtocol {
    var ignoredWhenSingleAsset: Bool = false
}

class WalletHideCommandProtocolMock: WalletCommandProtocolMock, WalletHideCommandProtocol {
    var actionType: WalletHideActionType = .dismiss
    var animated: Bool = false
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
