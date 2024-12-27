import Foundation
import SSFModels
import BigInt
import SSFTransferService
import TonSwift

final class TonTransferFlowUseCase: TransferFlowUseCase {
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    let interactor: TransferInteractorInput
    let implType: TransferFlowDirectionImpl = .ton

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
    var onFeeEstimationFailure: ((Error) -> Void)?
    
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

        selectedChainAsset = chainAsset
        utilityChainAsset = chainAsset.chain.utilityChainAssets().first

        provideInputViewModel?()
        provideAssetViewModel?()
        provideRecipientViewModel?()
        provideNetworkViewModel?()

        try await fetchRequaredInfo(for: chainAsset)
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
                let availableBalance,
                let sendAmount = amount()
            else {
                throw TransferFlowUseCaseError.getValidatorsError
            }

            let balanceType: BalanceType = selectedChainAsset.isUtility
                ? .utility(balance: utilityBalance)
                : .orml(balance: availableBalance, utilityBalance: utilityBalance)

            let feeAndTip: Decimal = [fee, tip].compactMap { $0 }.reduce(0.0, +)
            let validators = [
                dataValidatingFactory.has(
                    fee: fee,
                    locale: locale
                ) { [weak self] in
                    guard let transfer = self?.getTransfer() else {
                        return
                    }
                    self?.refreshFee(for: transfer)
                },
                dataValidatingFactory.canPayFeeAndAmount(
                    balanceType: balanceType,
                    feeAndTip: feeAndTip,
                    sendAmount: sendAmount,
                    locale: locale
                )
            ]
            return validators
        }
    }

    func getTransfer() -> TransferType? {
        guard
            let availableInputBalance,
            let selectedChainAsset,
            let inputAmount = inputResult?.absoluteValue(from: availableInputBalance),
            let amount = inputAmount.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision)),
            let address = try? wallet.fetch(for: selectedChainAsset.chain.accountRequest())?.accountId.asTonAddress(),
            let recipientAddress = getRecipientAddress(),
            let contract = wallet.ecosystem.tonWalletContract()
        else {
            return nil
        }

        let isMax = availableBalance == inputAmount

        let token: Token
        switch selectedChainAsset.asset.assetType.tonAssetType {
        case .normal:
            token = .ton
        case .jetton:
            guard let jettonWalletAddress = try? TonSwift.Address.parse(selectedChainAsset.asset.id) else {
                return nil
            }
            token = .jetton(jettonWalletAddress: jettonWalletAddress)
        case .none:
            return nil
        }

        let tonTransfer = TonTransfer(
            amount: amount,
            token: token,
            isMax: isMax,
            contract: contract,
            sender: address,
            recipientAddress: recipientAddress,
            comment: comment
        )
        let transfer = TransferType.ton(tonTransfer)
        return transfer
    }
    
    func checkAccountIsActive() async -> Bool {
        true
    }

    // MARK: - Private methods

    private func calcFee() {
        guard
            let transfer = getTransfer(),
            let selectedChainAsset,
            let utilityChainAsset,
            let amount = amount(),
            amount > 0
        else {
            return
        }
        
        if let balance = utilityBalance, balance < 0.005 {
            onFeeEstimationFailure?(ConvenienceError(error: "You don't have enough tokens to cover the transaction fee and complete the transfer."))
            return

        }
        provideFeeViewModel?()
        Task { [weak self] in
            guard let self else { return }
            let stream = await self.interactor.estimateFee(
                transfer: transfer,
                chainAsset: selectedChainAsset
            )
            let precision = Int16(utilityChainAsset.asset.precision)
            let shouldUpdateInputViewModel = inputResult?.needsUpdateInputAfterChange == true

            do {
                for try await fee in stream {
                    self.fee = (Decimal.fromSubstrateAmount(fee, precision: precision)).flatMap {
                        return $0 * 1.1
                    }
                    
                    self.provideFeeViewModel?()

                    if shouldUpdateInputViewModel {
                        self.provideInputViewModel?()
                    }
                }
            } catch {
                logger.customError(error)
                onFeeEstimationFailure?(error)
            }
        }
    }

    private func getRecipientAddress() -> RecipientAddress? {
        guard let recipientAddress else {
            return nil
        }
        let recipient: RecipientAddress
        if let friendly = try? FriendlyAddress(string: recipientAddress) {
            recipient = .friendly(friendly)
        } else if let raw = try? TonSwift.Address.parse(recipientAddress) {
            recipient = .raw(raw)
        } else {
            return nil
        }
        return recipient
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
        provideInputViewModel?()

        if let utilityChainAsset {
            let utilityChainAssetBalance = await balance(
                for: utilityChainAsset,
                accountId: accountId,
                accountInfos: try await balancesTask
            )
            utilityBalance = utilityChainAssetBalance
        }

        availableInputBalance = availableBalance
        provideAssetViewModel?()
    }
}
