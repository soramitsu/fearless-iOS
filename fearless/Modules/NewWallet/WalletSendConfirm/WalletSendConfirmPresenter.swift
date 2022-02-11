import Foundation
import BigInt
import SoraFoundation
import IrohaCrypto
import SwiftUI

final class WalletSendConfirmPresenter {
    weak var view: WalletSendConfirmViewProtocol?
    let wireframe: WalletSendConfirmWireframeProtocol
    let interactor: WalletSendConfirmInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountViewModelFactory: AccountViewModelFactoryProtocol
    let dataValidatingFactory: BaseDataValidatingFactoryProtocol
    let logger: LoggerProtocol?
    let asset: AssetModel
    let receiverAddress: String
    let amount: Decimal
    let selectedAccount: MetaAccountModel
    let chain: ChainModel
    let walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    let transferFinishBlock: WalletTransferFinishBlock?
    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
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
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        receiverAddress: String,
        amount: Decimal,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.walletSendConfirmViewModelFactory = walletSendConfirmViewModelFactory
        self.logger = logger
        self.asset = asset
        self.receiverAddress = receiverAddress
        self.amount = amount
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.transferFinishBlock = transferFinishBlock
    }

    private func provideViewModel() {
        let viewModel = walletSendConfirmViewModelFactory.buildViewModel(
            amount: amount,
            senderAccountViewModel: provideSenderAccountViewModel(),
            receiverAccountViewModel: provideReceiverAccountViewModel(),
            assetBalanceViewModel: provideAssetVewModel(),
            feeViewModel: provideFeeViewModel(),
            locale: selectedLocale
        )

        view?.didReceive(state: .loaded(viewModel))
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
        let addressFactory = SS58AddressFactory()

        guard let accountId = selectedAccount.fetch(for: chain.accountRequest())?.accountId,
              let senderAddress = try? addressFactory.address(fromAccountId: accountId, type: chain.addressPrefix) else {
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

    private func provideFeeViewModel() -> BalanceViewModelProtocol? {
        fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
    }

    private func refreshFee() {
        guard let amount = amount.toSubstrateAmount(precision: Int16(asset.precision)) else {
            return
        }

        interactor.estimateFee(for: amount)
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmPresenterProtocol {
    func setup() {
        interactor.setup()

        provideViewModel()

        view?.didReceive(title: R.string.localizable.walletSendNavigationTitle(
            asset.id,
            preferredLanguages: selectedLocale.rLanguages
        ))

        refreshFee()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapConfirmButton() {
        let sendAmountValue = amount.toSubstrateAmount(precision: Int16(asset.precision)) ?? 0
        let spendingValue = sendAmountValue +
            (fee?.toSubstrateAmount(precision: Int16(asset.precision)) ?? 0)

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
                locale: selectedLocale
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.view?.didStartLoading()
            strongSelf.interactor.submitExtrinsic(for: sendAmountValue, receiverAddress: strongSelf.receiverAddress)
        }
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmInteractorOutputProtocol {
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            transferFinishBlock?()

            let title = R.string.localizable
                .commonTransactionSubmitted(preferredLanguages: selectedLocale.rLanguages)

            wireframe.complete(on: view, title: title)
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

extension WalletSendConfirmPresenter: Localizable {
    func applyLocalization() {}
}
