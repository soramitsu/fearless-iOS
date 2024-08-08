import Foundation
import SSFModels
import SSFQRService
import BigInt
import SSFTransferService

final class SoraQrTransferFlowUseCase: TransferFlowUseCase {
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    let interactor: TransferInteractorInput
    let implType: TransferFlowDirectionImpl = .soraMainnetQr
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
    var canSelectAsset: Bool = false
    var isValidRecipient: Bool? = true
    var canEditRecipient: Bool = false
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
        guard case let .soraMainnet(qrInfo) = initialData else {
            throw TransferFlowUseCaseError.wrongType
        }
        let possibleChains = await interactor.getPossibleChains(for: qrInfo.address)
        let chainAsset = possibleChains
            .first(where: { $0.isSora })?.chainAssets
            .first(where: { $0.asset.currencyId == qrInfo.assetId })

        guard let qrChainAsset = chainAsset else {
            throw TransferFlowUseCaseError.unsupportedAsset
        }

        selectedChainAsset = qrChainAsset
        utilityChainAsset = qrChainAsset.chain.utilityChainAssets().first

        if let qrAmount = Decimal(string: qrInfo.amount ?? "") {
            inputResult = .absolute(qrAmount)
            isUserInteractiveAmount = false
            provideInputViewModel?()
        }

        await interactor.subscribeToPrice(for: qrChainAsset)

        recipientAddress = qrInfo.address
        provideRecipientViewModel?()
        provideNetworkViewModel?()
        provideAssetViewModel?()

        try await fetchRequaredInfo(for: qrChainAsset)
        calcFee()
    }

    func getValidators(
        validationCase: TransferValidationCase,
        locale: Locale
    ) throws -> [DataValidating] {
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
        guard let transfer = buildSubstrateTransfer() else {
            return
        }
        refreshFee(for: transfer)
    }

    private func fetchRequaredInfo(for chainAsset: ChainAsset) async throws {
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
