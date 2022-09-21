import Foundation
import BigInt
import SoraFoundation
import CommonWallet

final class WalletSendPresenter {
    weak var view: WalletSendViewProtocol?
    let wireframe: WalletSendWireframeProtocol
    let interactor: WalletSendInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: BaseDataValidatingFactoryProtocol
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    let receiverAddress: String
    let transferFinishBlock: WalletTransferFinishBlock?
    private let scamInfo: ScamInfo?

    private weak var moduleOutput: WalletSendModuleOutput?

    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var tip: Decimal?
    private var fee: Decimal?
    private var minimumBalance: BigUInt?
    private var inputResult: AmountInputResult?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    private var amountViewModel: AmountInputViewModelProtocol?

    init(
        interactor: WalletSendInteractorInputProtocol,
        wireframe: WalletSendWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset,
        receiverAddress: String,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.chainAsset = chainAsset
        self.receiverAddress = receiverAddress
        self.scamInfo = scamInfo
        self.transferFinishBlock = transferFinishBlock
        self.localizationManager = localizationManager
    }

    private func provideAssetVewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceive(assetBalanceViewModel: viewModel)
    }

    private func provideTipViewModel() {
        let viewModel = tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
        let tipViewModel = TipViewModel(
            balanceViewModel: viewModel,
            tipRequired: chainAsset.chain.isTipRequired
        )
        view?.didReceive(tipViewModel: tipViewModel)
    }

    private func provideFeeViewModel() {
        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
        view?.didReceive(feeViewModel: viewModel)
    }

    private func provideInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        amountViewModel = inputViewModel
        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func provideScamInfo() {
        view?.didReceive(scamInfo: scamInfo)
    }

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0
        guard let amount = inputAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return
        }

        view?.didStartFeeCalculation()

        let tip = self.tip?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        interactor.estimateFee(for: amount, tip: tip)
    }
}

extension WalletSendPresenter: WalletSendPresenterProtocol {
    func setup() {
        interactor.setup()

        provideInputViewModel()
        provideAssetVewModel()
        provideFeeViewModel()
        provideTipViewModel()
        provideScamInfo()

        if !chainAsset.chain.isTipRequired {
            // To not distract users with two different fees one by one, let's wait for tip, and then refresh fee
            refreshFee()
        }
    }

    func selectAmountPercentage(_ percentage: Float) {
        amountViewModel = nil
        inputResult = .rate(Decimal(Double(percentage)))

        refreshFee()
        provideAssetVewModel()
        provideInputViewModel()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        refreshFee()
        provideAssetVewModel()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapContinueButton() {
        let sendAmountDecimal = inputResult?.absoluteValue(from: balanceMinusFee)
        let sendAmountValue = sendAmountDecimal?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let spendingValue = (sendAmountValue ?? 0) +
            (fee?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) ?? 0)

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: sendAmountDecimal,
                locale: selectedLocale
            ),

            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingValue,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance,
                locale: selectedLocale,
                chainAsset: chainAsset
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self, let amount = sendAmountDecimal else { return }
            strongSelf.wireframe.presentConfirm(
                from: strongSelf.view,
                chainAsset: strongSelf.chainAsset,
                receiverAddress: strongSelf.receiverAddress,
                amount: amount,
                tip: strongSelf.tip,
                scamInfo: strongSelf.scamInfo,
                transferFinishBlock: strongSelf.transferFinishBlock
            )
        }
    }
}

extension WalletSendPresenter: WalletSendInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.available, precision: Int16(chainAsset.asset.precision))
            } ?? 0.0

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideAssetVewModel()
            provideFeeViewModel()
            provideTipViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        view?.didStopFeeCalculation()
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
            } ?? nil

            provideAssetVewModel()
            provideInputViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveTip(result: Result<BigUInt, Error>) {
        view?.didStopTipCalculation()
        switch result {
        case let .success(tip):
            self.tip = Decimal.fromSubstrateAmount(tip, precision: Int16(chainAsset.asset.precision))

            provideTipViewModel()
            refreshFee()
        case let .failure(error):
            logger?.error("Did receive tip error: \(error)")

            // Even though no tip received, let's refresh fee, because we didn't load it at start
            refreshFee()
        }
    }
}

extension WalletSendPresenter: Localizable {
    func applyLocalization() {}
}
