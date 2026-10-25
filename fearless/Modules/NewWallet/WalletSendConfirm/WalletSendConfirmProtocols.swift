import BigInt
import Foundation
import SSFModels

protocol WalletSendConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(state: WalletSendConfirmViewState)
    func didReceive(isLoading: Bool)
}

protocol WalletSendConfirmPresenterProtocol: AnyObject {
    func setup()
    func didTapConfirmButton()
    func didTapBackButton()
    func didTapScamWarningButton()
}

protocol WalletSendConfirmInteractorInputProtocol: AnyObject {
    var dependencyContainer: SendDepencyContainer { get }

    func setup()
    func submitExtrinsic()
    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset?
    func fetchEquilibriumTotalBalance(chainAsset: ChainAsset, amount: Decimal)
    func provideConstants()
    func confirmFeePresentation(fee: BigUInt, completion: @escaping (Bool) -> Void)
    func acknowledgeSubmittedTransfer(
        hash: String,
        recoveredIdentity: TonTransferIntentIdentity?,
        completion: @escaping (Bool) -> Void
    )
    func refreshFee()
    /// Broadcasts an already signed, unresolved transaction again; reports through `didTransfer`.
    func retryUnresolvedTransfer(hash: String)
    /// Lets the next transfer replace an unresolved one by spending the same coins.
    func allowReplacingUnresolvedTransfer(hash: String, completion: @escaping (Bool) -> Void)
}

/// Production success routing invokes the callback only after the all-done controller has
/// actually been presented. TON keeps its confirmed tombstone until this receipt boundary.
protocol WalletSendConfirmCompletionPresenting: AnyObject {
    func completeAfterPresentation(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset,
        completion: @escaping () -> Void
    )
}

protocol WalletSendConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(eqTotalBalance: Decimal)
    func didTransfer(result: Result<String, Error>)
    /// The rate of the fee that follows, for networks that price by size (Bitcoin, sat/vB).
    func didReceiveFeeRate(satPerVbyte: Double)
    /// The part of the fee that follows which opens the recipient's Solana token account
    /// (zero when no account is opened).
    func didReceiveAccountCreationDeposit(_ deposit: BigUInt)
}

extension WalletSendConfirmInteractorOutputProtocol {
    func didReceiveFeeRate(satPerVbyte _: Double) {}
    func didReceiveAccountCreationDeposit(_: BigUInt) {}
}

protocol WalletSendConfirmWireframeProtocol:
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting,
    SheetAlertPresentable,
    SendUnavailableReceivePresenting {
    func close(view: ControllerBackedProtocol?)
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    )
}

/// Solana screen ownership is separate from durable payment authority. Departure can revoke
/// future work and UI delivery, but never removes a retained signed transaction.
protocol WalletSendConfirmScopeManaging: AnyObject {
    var hasOwnedRecoveryPresentation: Bool { get }
    func resumeSendReview()
    func suspendSendReview()
}

protocol WalletSendConfirmAttemptManaging: AnyObject {
    var isSendSelectionCurrent: Bool { get }
    func cancelSendAttempt()
}
