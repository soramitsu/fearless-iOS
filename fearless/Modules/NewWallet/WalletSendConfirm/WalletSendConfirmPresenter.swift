import Foundation
import BigInt
import SoraFoundation
import IrohaCrypto
import SwiftUI

final class WalletSendConfirmPresenter {
    weak var view: WalletSendConfirmViewProtocol?
    private let wireframe: WalletSendConfirmWireframeProtocol
    private let interactor: WalletSendConfirmInteractorInputProtocol
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let receiverAddress: String
    private let amount: Decimal
    private let wallet: MetaAccountModel
    private let walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    private let scamInfo: ScamInfo?

    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var utilityBalance: Decimal?
    private var priceData: PriceData?
    private var utilityPriceData: PriceData?
    private var tip: Decimal?
    private var fee: Decimal?
    private var blockDuration: BlockTime?
    private var minimumBalance: BigUInt?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    init(
        interactor: WalletSendConfirmInteractorInputProtocol,
        wireframe: WalletSendConfirmWireframeProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.accountViewModelFactory = accountViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.walletSendConfirmViewModelFactory = walletSendConfirmViewModelFactory
        self.logger = logger
        self.chainAsset = chainAsset
        self.receiverAddress = receiverAddress
        self.amount = amount
        self.tip = tip
        self.wallet = wallet
        self.scamInfo = scamInfo
    }

    private func provideViewModel() {
        let parameters = WalletSendConfirmViewModelFactoryParameters(
            amount: amount,
            senderAccountViewModel: provideSenderAccountViewModel(),
            receiverAccountViewModel: provideReceiverAccountViewModel(),
            assetBalanceViewModel: provideAssetVewModel(),
            tipRequired: chainAsset.chain.isTipRequired,
            tipViewModel: provideTipViewModel(),
            feeViewModel: provideFeeViewModel(),
            wallet: wallet,
            locale: selectedLocale,
            scamInfo: scamInfo
        )
        let viewModel = walletSendConfirmViewModelFactory.buildViewModel(
            parameters: parameters
        )

        DispatchQueue.main.async {
            self.view?.didReceive(state: .loaded(viewModel))
        }
    }

    private func provideReceiverAccountViewModel() -> AccountViewModel? {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: receiverAddress,
            locale: selectedLocale
        )
    }

    private func provideSenderAccountViewModel() -> AccountViewModel? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
              let senderAddress = try? AddressFactory.address(for: accountId, chain: chainAsset.chain)
        else {
            return nil
        }

        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: senderAddress,
            locale: selectedLocale
        )
    }

    private func provideAssetVewModel() -> AssetBalanceViewModelProtocol? {
        guard let balanceViewModelFactory = interactor
            .dependencyContainer
            .prepareDepencies(chainAsset: chainAsset)?.balanceViewModelFactory else { return nil }
        return balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func provideTipViewModel() -> BalanceViewModelProtocol? {
        guard let utilityAsset = interactor.getUtilityAsset(for: chainAsset),
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: utilityAsset)?
              .balanceViewModelFactory else { return nil }
        return tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func provideFeeViewModel() -> BalanceViewModelProtocol? {
        guard let utilityAsset = interactor.getUtilityAsset(for: chainAsset),
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: utilityAsset)?
              .balanceViewModelFactory else { return nil }
        return fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func refreshFee() {
        guard let utilityAsset = interactor.getUtilityAsset(for: chainAsset),
              let amount = amount.toSubstrateAmount(precision: Int16(utilityAsset.asset.precision)) else {
            return
        }

        let tip = self.tip?.toSubstrateAmount(precision: Int16(utilityAsset.asset.precision))
        interactor.estimateFee(for: amount, tip: tip)
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmPresenterProtocol {
    func didTapScamWarningButton() {
        let title = R.string.localizable.scamWarningAlertTitle(
            chainAsset.asset.symbol.uppercased(),
            preferredLanguages: selectedLocale.rLanguages
        )
        let message = R.string.localizable.scamWarningAlertSubtitle(
            chainAsset.asset.name,
            preferredLanguages: selectedLocale.rLanguages
        )

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        )
        wireframe.present(
            viewModel: sheetViewModel,
            from: view
        )
    }

    func setup() {
        interactor.setup()

        provideViewModel()

        refreshFee()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapConfirmButton() {
        let sendAmountValue = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) ?? 0
        let spendingValue = sendAmountValue +
            (fee?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) ?? 0)

        let balanceType: BalanceType = (!chainAsset.isUtility && chainAsset.chain.isSora) ?
            .orml(balance: balance, utilityBalance: utilityBalance) : .utility(balance: balance)

        var minimumBalanceDecimal: Decimal?
        if let minBalance = minimumBalance {
            minimumBalanceDecimal = Decimal.fromSubstrateAmount(
                minBalance,
                precision: Int16(chainAsset.asset.precision)
            )
        }

        let edParameters: ExistentialDepositValidationParameters = chainAsset.isUtility ?
            .utility(
                spendingAmount: spendingValue,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance
            ) :
            .orml(
                minimumBalance: minimumBalanceDecimal,
                feeAndTip: (fee ?? 0) + (tip ?? 0),
                utilityBalance: utilityBalance
            )

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: (fee ?? 0) + (tip ?? 0),
                sendAmount: amount,
                locale: selectedLocale
            ),

            dataValidatingFactory.exsitentialDepositIsNotViolated(
                parameters: edParameters,
                locale: selectedLocale,
                chainAsset: chainAsset
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            let tip = strongSelf.tip?.toSubstrateAmount(
                precision: Int16(strongSelf.chainAsset.asset.precision)
            )

            strongSelf.view?.didStartLoading()
            strongSelf.interactor.submitExtrinsic(
                for: sendAmountValue,
                tip: tip,
                receiverAddress: strongSelf.receiverAddress
            )
        }
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmInteractorOutputProtocol {
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(hash):

            wireframe.complete(on: view, title: hash)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == self.chainAsset {
                totalBalanceValue = accountInfo?.data.total ?? 0
                balance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? 0.0

                provideViewModel()
            } else {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(self.chainAsset.asset.precision)
                    )
                } ?? 0
            }
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

    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId?) {
        switch result {
        case let .success(priceData):
            if chainAsset.asset.priceId == priceId {
                self.priceData = priceData
            } else {
                utilityPriceData = priceData
            }
            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            guard let utilityAsset = interactor.getUtilityAsset(for: chainAsset) else { return }
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(utilityAsset.asset.precision))
            } ?? nil

            provideViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }
}

extension WalletSendConfirmPresenter: Localizable {
    func applyLocalization() {}
}
