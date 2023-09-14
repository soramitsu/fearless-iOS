import Foundation
import SoraFoundation
import SSFModels
import BigInt

final class NftSendConfirmPresenter {
    // MARK: Private properties

    private weak var view: NftSendConfirmViewInput?
    private let router: NftSendConfirmRouterInput
    private let interactor: NftSendConfirmInteractorInput
    private let scamInfo: ScamInfo?
    private let receiverAddress: String
    private let wallet: MetaAccountModel
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let nft: NFT
    private var fee: Decimal?
    private let logger: LoggerProtocol?
    private let nftViewModelFactory: NftSendConfirmViewModelFactoryProtocol
    private var balance: Decimal?

    // MARK: - Constructors

    init(
        interactor: NftSendConfirmInteractorInput,
        router: NftSendConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        scamInfo: ScamInfo?,
        receiverAddress: String,
        wallet: MetaAccountModel,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        nft: NFT,
        logger: LoggerProtocol?,
        nftViewModelFactory: NftSendConfirmViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.scamInfo = scamInfo
        self.receiverAddress = receiverAddress
        self.wallet = wallet
        self.nft = nft
        self.accountViewModelFactory = accountViewModelFactory
        self.logger = logger
        self.nftViewModelFactory = nftViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideNftViewModel() {
        let viewModel = nftViewModelFactory.buildViewModel(nft: nft)
        view?.didReceive(nftViewModel: viewModel)
    }

    private func provideReceiverAccountViewModel() {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: selectedLocale.rLanguages)

        let viewModel = accountViewModelFactory.buildViewModel(
            title: title,
            address: receiverAddress,
            locale: selectedLocale
        )

        view?.didReceive(receiverViewModel: viewModel)
    }

    private func provideSenderAccountViewModel() {
        guard let accountId = wallet.fetch(for: nft.chain.accountRequest())?.accountId,
              let senderAddress = try? AddressFactory.address(for: accountId, chain: nft.chain)
        else {
            return
        }

        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: selectedLocale.rLanguages)

        let viewModel = accountViewModelFactory.buildViewModel(
            title: title,
            address: senderAddress,
            locale: selectedLocale
        )

        view?.didReceive(senderViewModel: viewModel)
    }

    private func provideFeeViewModel() {
        guard
            let utilityAsset = nft.chain.utilityChainAssets().first,
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }
        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: nil, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        view?.didReceive(feeViewModel: viewModel)
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }
}

// MARK: - NftSendConfirmViewOutput

extension NftSendConfirmPresenter: NftSendConfirmViewOutput {
    func didLoad(view: NftSendConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideSenderAccountViewModel()
        provideReceiverAccountViewModel()
        provideNftViewModel()

        interactor.estimateFee(for: nft, address: receiverAddress)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didConfirmButtonTapped() {
        view?.didStartLoading()

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: balance),
                feeAndTip: fee ?? 0,
                sendAmount: 0,
                locale: selectedLocale
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.interactor.submitExtrinsic(
                nft: strongSelf.nft,
                receiverAddress: strongSelf.receiverAddress
            )
        }
    }
}

// MARK: - NftSendConfirmInteractorOutput

extension NftSendConfirmPresenter: NftSendConfirmInteractorOutput {
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case let .success(hash):
            if let chainAsset = nft.chain.utilityChainAssets().first {
                router.complete(on: view, title: hash, chainAsset: chainAsset)
            }
        case let .failure(error):
            if !router.present(error: error, from: view, locale: selectedLocale) {
                router.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            guard let chainAsset = nft.chain.utilityChainAssets().first else { return }
            fee = BigUInt(string: dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            balance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(chainAsset.asset.precision)
                )
            } ?? 0.0
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }
}

// MARK: - Localizable

extension NftSendConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension NftSendConfirmPresenter: NftSendConfirmModuleInput {}
