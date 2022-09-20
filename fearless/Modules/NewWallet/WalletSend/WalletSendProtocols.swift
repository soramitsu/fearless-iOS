import Foundation
import BigInt

protocol WalletSendViewProtocol: ControllerBackedProtocol {
    func didReceive(state: WalletSendViewState)
    func didStartFeeCalculation()
    func didStopFeeCalculation()
    func didStopTipCalculation()
}

protocol WalletSendPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func didTapBackButton()
    func didTapContinueButton()
}

protocol WalletSendInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt, tip: BigUInt?)
}

protocol WalletSendInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveTip(result: Result<BigUInt, Error>)
}

protocol WalletSendWireframeProtocol: AlertPresentable, ErrorPresentable, BaseErrorPresentable {
    func close(view: ControllerBackedProtocol?)
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    )
}

protocol WalletSendModuleOutput: AnyObject {
    func transferDidComplete()
}
