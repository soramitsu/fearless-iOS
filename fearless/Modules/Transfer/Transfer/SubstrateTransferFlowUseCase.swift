import Foundation
import SSFModels
import SSFQRService
import BigInt
import SSFTransferService

final class SubstrateTransferFlowUseCase: TransferFlowUseCase {
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    let interactor: TransferInteractorInput
    let implType: TransferFlowDirectionImpl = .substrate

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

    var sendAllEnabled: Bool? = false
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
        self.dataValidatingFactory = dataValidatingFactory
        self.interactor = interactor
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

        try await fetchRequaredInfo(for: chainAsset)
        calcFee()
    }

    func getValidators(
        validationCase: TransferValidationCase,
        locale: Locale
    ) throws -> [any DataValidating] {
        guard
            let selectedChainAsset,
            let availableInputBalance,
            let inputResult,
            let utilityBalance
        else {
            throw TransferFlowUseCaseError.getValidatorsError
        }
        let sendAmount = inputResult.absoluteValue(from: availableInputBalance)

        let spending: Decimal
        if selectedChainAsset.isUtility {
            spending = sendAmount + fee.or(.zero) + tip.or(.zero)
        } else {
            spending = fee.or(.zero) + tip.or(.zero)
        }
        let exsitentialDepositIsNotViolated = dataValidatingFactory.exsitentialDepositIsNotViolated(
            spending: spending,
            balance: utilityBalance,
            minimumBalance: ed.or(.zero),
            chainAsset: selectedChainAsset,
            locale: locale,
            sendAllEnabled: sendAllEnabled ?? false,
            proceedAction: { [weak self] in
                self?.sendAllEnabled = true
                self?.provideAssetViewModel?()
            },
            setMaxAction: { [weak self] in
                self?.sendAllEnabled = true
                self?.inputResult = .rate(1.0)
                self?.provideAssetViewModel?()
                self?.provideInputViewModel?()
                self?.refreshFee(for: self?.getTransfer())
            },
            cancelAction: { [weak self] in
                self?.sendAllEnabled = false
                self?.inputResult = .rate(0.0)
                self?.provideAssetViewModel?()
                self?.provideInputViewModel?()
            }
        )
        switch validationCase {
        case .validateED:
            return [exsitentialDepositIsNotViolated]
        case .all:
            let balanceType: BalanceType = selectedChainAsset.isUtility
                ? .utility(balance: utilityBalance)
                : .orml(balance: availableBalance, utilityBalance: utilityBalance)

            return [
                exsitentialDepositIsNotViolated,
                dataValidatingFactory.has(
                    fee: fee,
                    locale: locale,
                    onError: { [weak self] in
                        self?.refreshFee(for: self?.getTransfer())
                    }
                ),
                dataValidatingFactory.canPayFeeAndAmount(
                    balanceType: balanceType,
                    feeAndTip: (fee ?? 0) + (tip ?? 0),
                    sendAmount: sendAmount,
                    locale: locale
                )
            ]
        }
    }

    func getTransfer() -> TransferType? {
        buildSubstrateTransfer()
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
        async let tipTask = await interactor.fetchTip(for: chainAsset)
        async let edTask = await interactor.fetchExistentialDeposit(for: chainAsset)

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

            do {
                let tip = try await Decimal.fromSubstrateAmount(
                    tipTask,
                    precision: Int16(utilityChainAsset.asset.precision)
                )
                self.tip = tip
                provideTipViewModel?()
            } catch {
                logger.customError(error)
            }

            do {
                let ed = try await Decimal.fromSubstrateAmount(
                    edTask,
                    precision: Int16(utilityChainAsset.asset.precision)
                )
                self.ed = ed
            } catch {
                logger.customError(error)
            }

            isSwitchEnableSendAllVisibility = await [
                try? edTask > .zero,
                availableBalance.or(.zero) > .zero,
                selectedChainAsset?.isUtility == true
            ].compactMap { $0 }.allSatisfy { $0 }
        }

        await calcAvailableInputBalance()
        provideInputViewModel?()
        provideAssetViewModel?()
    }
}
