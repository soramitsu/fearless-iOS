import Foundation
import BigInt
import SoraFoundation
import IrohaCrypto
import SwiftUI

final class WalletSendConfirmPresenter {
    weak var view: WalletSendConfirmViewProtocol?
    private let wireframe: WalletSendConfirmWireframeProtocol
    private let interactor: WalletSendConfirmInteractorInputProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let dataValidatingFactory: BaseDataValidatingFactoryProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let receiverAddress: String
    private let amount: Decimal
    private let selectedAccount: MetaAccountModel
    private let walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    private let scamInfo: ScamInfo?

    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var tip: Decimal?
    private var fee: Decimal?
    private var blockDuration: BlockTime?
    private var minimumBalance: BigUInt?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    init(
        interactor: WalletSendConfirmInteractorInputProtocol,
        wireframe: WalletSendConfirmWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
        walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.walletSendConfirmViewModelFactory = walletSendConfirmViewModelFactory
        self.logger = logger
        self.chainAsset = chainAsset
        self.receiverAddress = receiverAddress
        self.amount = amount
        self.tip = tip
        self.selectedAccount = selectedAccount
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
            wallet: selectedAccount,
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
        guard let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
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
        balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func provideTipViewModel() -> BalanceViewModelProtocol? {
        tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func provideFeeViewModel() -> BalanceViewModelProtocol? {
        fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func refreshFee() {
        guard let amount = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return
        }

        let tip = self.tip?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        interactor.estimateFee(for: amount, tip: tip)
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmPresenterProtocol {
    func didTapScamWarningButton() {
        let closeAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            style: UIFactory.default.createMainActionButton(),
            handler: nil
        )
        let title = R.string.localizable.scamWarningAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        let subtitle = R.string.localizable.scamWarningAlertSubtitle(
            chainAsset.asset.name,
            preferredLanguages: selectedLocale.rLanguages
        )

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            titleStyle: .defaultTitle,
            subtitle: subtitle,
            subtitleStyle: .defaultSubtitle,
            actions: [closeAction]
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

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
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

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.available, precision: Int16(chainAsset.asset.precision))
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
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
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
