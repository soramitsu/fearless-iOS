import Foundation
import SoraFoundation
import BigInt
import SSFModels

final class NftSendPresenter {
    // MARK: Private properties

    private weak var view: NftSendViewInput?
    private let router: NftSendRouterInput
    private let interactor: NftSendInteractorInput
    private let nft: NFT
    private let wallet: MetaAccountModel
    private let logger: LoggerProtocol
    private let viewModelFactory: SendViewModelFactoryProtocol

    private var recipientAddress: String?
    private var fee: Decimal?
    private var scamInfo: ScamInfo?

    // MARK: - Constructors

    init(
        interactor: NftSendInteractorInput,
        router: NftSendRouterInput,
        localizationManager: LocalizationManagerProtocol,
        nft: NFT,
        wallet: MetaAccountModel,
        logger: LoggerProtocol,
        viewModelFactory: SendViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.nft = nft
        self.wallet = wallet
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    func handle(newAddress: String) {
        recipientAddress = newAddress
        interactor.estimateFee(for: nft, address: newAddress)

        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: newAddress,
            isValid: interactor.validate(address: newAddress, for: nft.chain).isValid
        )

        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }
    }

    func provideFeeViewModel() {
        guard
            let utilityAsset = nft.chain.utilityChainAssets().first,
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }

        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: nil, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(feeViewModel: viewModel)
        }
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

// MARK: - NftSendViewOutput

extension NftSendPresenter: NftSendViewOutput {
    func didLoad(view: NftSendViewInput) {
        self.view = view
        interactor.setup(with: self)

        interactor.estimateFee(for: nft, address: nil)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didTapPasteButton() {
        if let address = UIPasteboard.general.string {
            handle(newAddress: address)
        }
    }

    func didTapScanButton() {
        router.presentScan(from: view, moduleOutput: self)
    }

    func didTapHistoryButton() {
        router.presentHistory(from: view, wallet: wallet, chain: nft.chain, moduleOutput: self)
    }

    func didTapContinueButton() {
        guard let receiver = recipientAddress else {
            return
        }

        router.presentConfirm(nft: nft, receiver: receiver, scamInfo: scamInfo, wallet: wallet, from: view)
    }

    func searchTextDidChanged(_ text: String) {
        handle(newAddress: text)
    }
}

// MARK: - NftSendInteractorOutput

extension NftSendPresenter: NftSendInteractorOutput {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
//        view?.didStopFeeCalculation()
        switch result {
        case let .success(dispatchInfo):
            guard let chainAsset = nft.chain.utilityChainAssets().first else { return }
            fee = BigUInt(string: dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive fee error: \(error)")
        }
    }

    func didReceive(scamInfo: ScamInfo?) {
        self.scamInfo = scamInfo
        view?.didReceive(scamInfo: scamInfo)
    }
}

// MARK: - Localizable

extension NftSendPresenter: Localizable {
    func applyLocalization() {}
}

extension NftSendPresenter: NftSendModuleInput {}

extension NftSendPresenter: ScanQRModuleOutput {
    func didFinishWithSolomon(soraAddress _: String) {}

    func didFinishWith(address: String) {
        handle(newAddress: address)
    }
}

extension NftSendPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        handle(newAddress: address)
    }
}
