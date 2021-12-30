import Foundation
import BigInt
import SoraFoundation
import CommonWallet

final class WalletSendPresenter {
    weak var view: WalletSendViewProtocol?
    let wireframe: WalletSendWireframeProtocol
    let interactor: WalletSendInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountViewModelFactory: AccountViewModelFactoryProtocol
    let dataValidatingFactory: BaseDataValidatingFactoryProtocol
    let logger: LoggerProtocol?
    let asset: AssetModel
    let chain: ChainModel
    let receiverAddress: String

    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var blockDuration: BlockTime?
    private var minimumBalance: BigUInt?
    private var inputResult: AmountInputResult?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    init(
        interactor: WalletSendInteractorInputProtocol,
        wireframe: WalletSendWireframeProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        asset: AssetModel,
        receiverAddress: String,
        chain: ChainModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.accountViewModelFactory = accountViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.asset = asset
        self.receiverAddress = receiverAddress
        self.chain = chain
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = WalletSendViewModel(
            accountViewModel: provideAccountViewModel(),
            assetBalanceViewModel: provideAssetVewModel(),
            feeViewModel: provideFeeViewModel(),
            amountInputViewModel: provideInputViewModel()
        )

        view?.didReceive(state: .loaded(viewModel))
    }

    private func provideAccountViewModel() -> AccountViewModel? {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: receiverAddress,
            locale: selectedLocale
        )
    }

    private func provideAssetVewModel() -> AssetBalanceViewModelProtocol? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0

        return balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func provideFeeViewModel() -> BalanceViewModelProtocol? {
        fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func provideInputViewModel() -> AmountInputViewModelProtocol? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        return balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
    }

    private func provideInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideInputViewModel()
    }

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0
        guard let amount = inputAmount.toSubstrateAmount(precision: Int16(asset.precision)) else {
            return
        }

        interactor.estimateFee(for: amount)
    }
}

extension WalletSendPresenter: WalletSendPresenterProtocol {
    func setup() {
        interactor.setup()

        provideViewModel()

        view?.didReceive(title: R.string.localizable.walletSendNavigationTitle(
            asset.id,
            preferredLanguages: selectedLocale.rLanguages
        ))
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        refreshFee()
        provideViewModel()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        refreshFee()
        provideViewModel()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapContinueButton() {
        let sendAmountDecimal = inputResult?.absoluteValue(from: balanceMinusFee)
        let sendAmountValue = sendAmountDecimal?.toSubstrateAmount(precision: Int16(asset.precision))
        let spendingValue = (sendAmountValue ?? 0) +
            (fee?.toSubstrateAmount(precision: Int16(asset.precision)) ?? 0)

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
                locale: selectedLocale
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self, let amount = sendAmountDecimal else { return }
            strongSelf.wireframe.presentConfirm(
                from: strongSelf.view,
                chain: strongSelf.chain,
                asset: strongSelf.asset,
                receiverAddress: strongSelf.receiverAddress,
                amount: amount
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
                Decimal.fromSubstrateAmount($0.data.available, precision: Int16(asset.precision))
            } ?? 0.0

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        switch result {
        case let .success(blockDuration):
            self.blockDuration = blockDuration

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive block duration error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(asset.precision))
            } ?? nil

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }
}

extension WalletSendPresenter: Localizable {
    func applyLocalization() {}
}
