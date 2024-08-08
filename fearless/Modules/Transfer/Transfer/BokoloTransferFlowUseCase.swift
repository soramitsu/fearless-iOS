import Foundation
import SSFModels
import SSFQRService
import BigInt
import SSFTransferService
import SSFUtils
import SSFCrypto

final class BokoloTransferFlowUseCase: TransferFlowUseCase {
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    let interactor: TransferInteractorInput
    let implType: TransferFlowDirectionImpl = .bokoloCash
    var transfer: TransferType?

    var selectedChainAsset: ChainAsset?
    var utilityChainAsset: ChainAsset?
    var comment: String?
    var inputResult: AmountInputResult? {
        didSet {
            refreshFee()
        }
    }

    var recipientAddress: String? {
        didSet {
            refreshFee()
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
    var isValidRecipient: Bool? = true
    var canEditRecipient: Bool = false
    var canSelectAsset: Bool = false
    var isSwitchEnableSendAllVisibility: Bool = false

    var provideRecipientViewModel: (() -> Void)?
    var provideAssetViewModel: (() -> Void)?
    var provideInputViewModel: (() -> Void)?
    var provideNetworkViewModel: (() -> Void)?
    var provideTipViewModel: (() -> Void)?
    var provideFeeViewModel: (() -> Void)?

    private var bokoloCashId: Data?
    private var bokoloSwapValues: SwapValues?

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
        guard case let .bokoloCash(qrInfo) = initialData else {
            throw TransferFlowUseCaseError.wrongType
        }

        let possibleChains = await interactor
            .getPossibleChains(
                for: BokoloConstants.bokoloCasheBridgeAddress
            )

//        #if F_DEV
//            let chainAsset = possibleChains
//                .first(where: { chain in
//                    switch chain.knownChainEquivalent {
//                    case .soraTest: return true
//                    default: return false
//                    }
//                })?
//                .chainAssets
//                .first(where: { $0.asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId })
//
//        #else
        let chainAsset = possibleChains
            .first(where: { chain in
                switch chain.knownChainEquivalent {
                case .soraMain: return true
                default: return false
                }
            })?
            .chainAssets
            .first(where: { $0.asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId })
//        #endif

        guard
            let qrChainAsset = chainAsset,
            let bokoloCashId = qrInfo.address.data(using: .utf8)
        else {
            throw TransferFlowUseCaseError.unsupportedAsset
        }

        self.bokoloCashId = bokoloCashId
        recipientAddress = qrInfo.address
        provideNetworkViewModel?()

        selectedChainAsset = qrChainAsset
        utilityChainAsset = qrChainAsset.chain.utilityChainAssets().first
        provideAssetViewModel?()
        provideRecipientViewModel?()

        if var qrAmount = Decimal(string: qrInfo.transactionAmount ?? ""), qrAmount != .zero {
            var drounded = Decimal()
            NSDecimalRound(&drounded, &qrAmount, 2, .plain)
            inputResult = .absolute(qrAmount)
            isUserInteractiveAmount = false
        }

        await interactor.subscribeToPrice(for: qrChainAsset)
        provideInputViewModel?()

        try await fetchRequaredInfo(for: qrChainAsset)
        transfer = try buildTransfer()
        refreshFee()
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
                let utilityBalance,
                let availableBalance
            else {
                throw TransferFlowUseCaseError.getValidatorsError
            }

            var sendAmountDecimal = inputResult?.absoluteValue(from: availableBalance)
            var balanceType: BalanceType
            var feeAndTip: Decimal
            var feeForValidation: Decimal?
            if let xorFee = fee, utilityBalance > xorFee {
                balanceType = .orml(balance: availableBalance, utilityBalance: utilityBalance)
                feeAndTip = xorFee
                feeForValidation = fee
            } else {
                balanceType = .utility(balance: availableBalance)
                feeAndTip = fee ?? .zero
                sendAmountDecimal = (sendAmountDecimal ?? .zero) - (fee ?? .zero)
                feeForValidation = fee
            }

            let validators = [
                dataValidatingFactory.has(fee: feeForValidation, locale: locale, onError: { [weak self] in
                    self?.refreshFee(for: self?.transfer)
                }),
                dataValidatingFactory.canPayFeeAndAmount(
                    balanceType: balanceType,
                    feeAndTip: feeAndTip,
                    sendAmount: sendAmountDecimal,
                    locale: locale
                )
            ]

            return validators
        }
    }

    // MARK: - Private methods

    private func refreshFee() {
        guard
            let transfer,
            let selectedChainAsset
        else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let stream = await self.interactor.estimateFee(
                transfer: transfer,
                chainAsset: selectedChainAsset
            )
            for try await fee in stream {
                let precision = Int16(selectedChainAsset.asset.precision)
                self.fee = Decimal.fromSubstrateAmount(fee, precision: precision)
                try await self.checkXorFeePaymentPossibles()
            }
        }
    }

    private func checkXorFeePaymentPossibles() async throws {
        guard
            let xorBalance = utilityBalance,
            let xorFee = fee
        else {
            provideFeeViewModel?()
            return
        }

        if xorBalance > xorFee {
            provideFeeViewModel?()
        } else {
            guard
                let bokoloChainAsset = selectedChainAsset,
                let xorChainAsset = utilityChainAsset,
                let feeValue = xorFee.toSubstrateAmount(precision: Int16(xorChainAsset.asset.precision))
            else {
                return
            }
            guard let bokoloSwap = try await interactor.convert(
                chainAsset: xorChainAsset,
                toChainAsset: bokoloChainAsset,
                amount: feeValue
            ) else {
                return
            }
            let bokoloAmount = BigUInt(bokoloSwap.amount) ?? .zero
            let bokoloFee = Decimal.fromSubstrateAmount(
                bokoloAmount,
                precision: Int16(bokoloChainAsset.asset.precision)
            )

            bokoloSwapValues = bokoloSwap
            fee = bokoloFee
            utilityChainAsset = bokoloChainAsset

            provideFeeViewModel?()
        }
    }

    private func buildTransfer() throws -> TransferType? {
        guard
            let availableInputBalance,
            let selectedChainAsset,
            let inputAmount = inputResult?.absoluteValue(from: availableInputBalance),
            let amount = inputAmount.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision))
        else {
            return nil
        }

        let address = BokoloConstants.bokoloCasheBridgeAddress
        let receiver = try AddressFactory.accountId(
            from: address,
            chain: selectedChainAsset.chain
        )

        let fee = fee?.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision)) ?? .zero
        let feeReserve = BigUInt(10_000_000_000_000_000)

        let maxAmountIn = ((self.fee ?? .zero) * 1.5).toSubstrateAmount(
            precision: Int16(selectedChainAsset.asset.precision)
        )
        let filter: PolkaswapLiquidityFilterMode = .disabled
        let filterMode = SSFTransferService.PolkaswapCallFilterModeType(
            wrappedName: filter.code,
            wrappedValue: nil
        )

        let dexId = String(bokoloSwapValues?.dexId ?? 0)
        let soraAssetId = SSFUtils.SoraAssetId(
            wrappedValue: BokoloConstants.bokoloCashAssetCurrencyId
        )
        let xorless = SSFTransferService.XorlessTransfer(
            dexId: dexId,
            assetId: soraAssetId,
            receiver: receiver,
            amount: amount,
            desiredXorAmount: fee + feeReserve,
            maxAmountIn: maxAmountIn ?? .zero,
            selectedSourceTypes: [],
            filterMode: filterMode,
            additionalData: bokoloCashId ?? Data()
        )
        let transfer = TransferType.xorless(xorless)
        return transfer
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
