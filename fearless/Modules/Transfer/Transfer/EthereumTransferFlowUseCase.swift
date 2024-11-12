import Foundation
import SSFModels
import BigInt
import SSFTransferService

final class EthereumTransferFlowUseCase: TransferFlowUseCase {
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    let interactor: TransferInteractorInput
    let implType: TransferFlowDirectionImpl = .ethereum
    var transfer: TransferType?

    var selectedChainAsset: ChainAsset?
    var utilityChainAsset: ChainAsset?
    var comment: String?
    var inputResult: AmountInputResult? {
        didSet {
            calcFee()
        }
    }

    var recipientAddress: String? {
        didSet {
            calcFee()
        }
    }

    var availableInputBalance: Decimal?
    var availableBalance: Decimal?
    var utilityBalance: Decimal?

    var fee: Decimal?
    var tip: Decimal?
    var ed: Decimal?

    var sendAllEnabled: Bool?
    var isUserInteractiveAmount: Bool = true
    var isValidRecipient: Bool? = false
    var canEditRecipient: Bool = true
    var canSelectAsset: Bool = true
    var isSwitchEnableSendAllVisibility: Bool = false

    var provideRecipientViewModel: (() -> Void)?
    var provideAssetViewModel: (() -> Void)?
    var provideInputViewModel: (() -> Void)?
    var provideNetworkViewModel: (() -> Void)?
    var provideTipViewModel: (() -> Void)?
    var provideFeeViewModel: (() -> Void)?

    init(
        wallet: MetaAccountModel,
        dataValidatingFactory: SendDataValidatingFactory,
        interactor: TransferInteractorInput,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.dataValidatingFactory = dataValidatingFactory
        self.wallet = wallet
        self.logger = logger
    }

    func handle(initialData: SendFlowInitialData) async throws {
        guard case let .chainAsset(chainAsset) = initialData else {
            throw TransferFlowUseCaseError.wrongType
        }
        provideRecipientViewModel?()

        selectedChainAsset = chainAsset
        utilityChainAsset = chainAsset.chain.utilityChainAssets().first

        provideNetworkViewModel?()

        try await fetchRequiredInfo(for: chainAsset)
        calcFee()
    }

    func getValidators(
        validationCase: TransferValidationCase,
        locale: Locale
    ) throws -> [any DataValidating] {
        switch validationCase {
        case .validateED:
            return []
        case .all:
            guard
                let selectedChainAsset,
                let availableInputBalance
            else {
                throw TransferFlowUseCaseError.getValidatorsError
            }

            let balanceType: BalanceType = selectedChainAsset.isUtility
                ? .utility(balance: utilityBalance)
                : .orml(balance: availableBalance, utilityBalance: utilityBalance)

            let sendAmount = inputResult?.absoluteValue(from: availableInputBalance)

            let validators = [
                dataValidatingFactory.has(
                    fee: fee,
                    locale: locale
                ) { [weak self] in
                    guard let transfer = self?.transfer else {
                        return
                    }
                    self?.refreshFee(for: transfer)
                },
                dataValidatingFactory.canPayFeeAndAmount(
                    balanceType: balanceType,
                    feeAndTip: fee.or(.zero) + tip.or(.zero),
                    sendAmount: sendAmount,
                    locale: locale
                )
            ]
            return validators
        }
    }

    // MARK: - Private methods

    private func calcFee() {
        guard let transfer = buildEthereumTransfer() else {
            return
        }
        refreshFee(for: transfer)
    }

    private func buildEthereumTransfer() -> TransferType? {
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

        let ethereumTransfer = EthereumTransfer(
            amount: amount,
            receiver: recipientAddress
        )
        let transfer = TransferType.ethereum(ethereumTransfer)
        self.transfer = transfer
        return transfer
    }

    private func fetchRequiredInfo(for chainAsset: ChainAsset) async throws {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw TransferFlowUseCaseError.missingAccount
        }

        async let balancesTask = try await interactor.fetchAccountInfos(for: chainAsset)

        let chainAssetBalance = await balance(
            for: chainAsset,
            accountId: accountId,
            accountInfos: try await balancesTask
        )
        availableBalance = chainAssetBalance

        if let utilityChainAsset {
            let utilityChainAssetBalance = await balance(
                for: utilityChainAsset,
                accountId: accountId,
                accountInfos: try await balancesTask
            )
            utilityBalance = utilityChainAssetBalance
        }

        await calcAvailableInputBalance()
        provideInputViewModel?()
        provideAssetViewModel?()
    }
}
