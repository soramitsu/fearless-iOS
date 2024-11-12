import Foundation
import SSFModels
import SSFQRService
import SSFTransferService

enum TransferFlowUseCaseError: Error {
    case wrongType
    case unsupportedAsset
    case missingAccount
    case getValidatorsError
}

enum TransferFlowDirectionImpl {
    case substrate
    case ethereum
    case soraMainnetQr
    case bokoloCash
    case ton
}

enum TransferValidationCase {
    case validateED
    case all
}

protocol TransferFlowUseCase: AnyObject {
    var interactor: TransferInteractorInput { get }
    var implType: TransferFlowDirectionImpl { get }
    var transfer: TransferType? { get set }

    var selectedChainAsset: ChainAsset? { get set }
    var utilityChainAsset: ChainAsset? { get set }
    var inputResult: AmountInputResult? { get set }
    var recipientAddress: String? { get set }
    var comment: String? { get set }

    var availableInputBalance: Decimal? { get set }
    var availableBalance: Decimal? { get set }
    var utilityBalance: Decimal? { get set }

    var fee: Decimal? { get set }
    var tip: Decimal? { get set }
    var ed: Decimal? { get set }

    var isUserInteractiveAmount: Bool { get set }
    var canSelectAsset: Bool { get }
    var isValidRecipient: Bool? { get set }
    var canEditRecipient: Bool { get set }
    var isSwitchEnableSendAllVisibility: Bool { get }
    var sendAllEnabled: Bool? { get set }

    var provideRecipientViewModel: (() -> Void)? { get set }
    var provideNetworkViewModel: (() -> Void)? { get set }
    var provideAssetViewModel: (() -> Void)? { get set }
    var provideInputViewModel: (() -> Void)? { get set }
    var provideTipViewModel: (() -> Void)? { get set }
    var provideFeeViewModel: (() -> Void)? { get set }

    func handle(initialData: SendFlowInitialData) async throws
    func reset() async
    func handleRecipient(address: String) async
    func isReadyToContinue() -> Bool
    func getValidators(
        validationCase: TransferValidationCase,
        locale: Locale
    ) throws -> [DataValidating]
}

extension TransferFlowUseCase {
    func amount() -> Decimal? {
        guard let availableInputBalance else {
            return nil
        }
        let amount = inputResult?.absoluteValue(from: availableInputBalance)
        return amount
    }

    func reset() async {
        transfer = nil
        selectedChainAsset = nil
        utilityChainAsset = nil
        inputResult = nil
        recipientAddress = nil
        availableInputBalance = nil
        availableBalance = nil
        utilityBalance = nil
        fee = nil
        tip = nil
        ed = nil
        isValidRecipient = nil
        comment = nil
    }

    func handleRecipient(address: String) async {
        recipientAddress = address
        guard address.isNotEmpty else {
            isValidRecipient = nil
            recipientAddress = nil
            provideRecipientViewModel?()
            return
        }

        guard let selectedChainAsset else {
            return
        }

        let isValid = await interactor.validate(address: address, for: selectedChainAsset.chain).isValid
        isValidRecipient = isValid
        provideRecipientViewModel?()
    }

    func isReadyToContinue() -> Bool {
        guard
            let availableInputBalance,
            let inputAmount = inputResult?.absoluteValue(from: availableInputBalance)
        else {
            return false
        }

        let allSatisfy = [
            recipientAddress != nil,
            inputAmount > 0
        ].allSatisfy { $0 }
        return allSatisfy
    }

    func balance(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        accountInfos: [ChainAssetKey: AccountInfo?]
    ) async -> Decimal? {
        let key = chainAsset.uniqueKey(accountId: accountId)
        let chainAssetAccountInfo = accountInfos[key] ?? nil
        let chainAssetBalance = chainAssetAccountInfo.map {
            Decimal.fromSubstrateAmount(
                $0.data.sendAvailable,
                precision: Int16(chainAsset.asset.precision)
            )
        } ?? .zero
        return chainAssetBalance
    }

    /// Before use this method make sure what calcAvailableInputBalance() suit for you case
    func refreshFee(for transfer: TransferType?) {
        guard
            let selectedChainAsset,
            let transfer,
            let utilityChainAsset
        else {
            return
        }
        provideFeeViewModel?()
        Task { [weak self] in
            guard let self else { return }
            let stream = await self.interactor.estimateFee(
                transfer: transfer,
                chainAsset: selectedChainAsset
            )
            for try await fee in stream {
                let precision = Int16(utilityChainAsset.asset.precision)
                self.fee = Decimal.fromSubstrateAmount(fee, precision: precision)
                self.provideFeeViewModel?()
                await calcAvailableInputBalance()
            }
        }
    }

    func buildSubstrateTransfer() -> TransferType? {
        guard
            let availableInputBalance,
            let selectedChainAsset,
            let recipientAddress,
            let inputAmount = inputResult?.absoluteValue(from: availableInputBalance),
            let amount = inputAmount.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision))
        else {
            transfer = nil
            return nil
        }
        let tip = tip?.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision))
        let subtrateTransfer = SubstrateTransfer(
            amount: amount,
            receiver: recipientAddress,
            tip: tip
        )
        let transfer = TransferType.substrate(subtrateTransfer)
        self.transfer = transfer
        return transfer
    }

    func calcAvailableInputBalance() async {
        guard
            let selectedChainAsset,
            let utilityChainAsset
        else {
            return
        }

        if selectedChainAsset.chainAssetId == utilityChainAsset.chainAssetId {
            availableInputBalance = availableBalance.or(.zero) - fee.or(.zero) - tip.or(.zero)
        } else {
            availableInputBalance = availableBalance
        }
        provideInputViewModel?()
    }
}
