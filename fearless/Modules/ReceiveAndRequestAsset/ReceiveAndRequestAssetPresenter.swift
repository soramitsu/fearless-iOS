import Foundation
import SoraFoundation
import SSFModels
import SSFUtils
import SSFQRService

protocol ReceiveAndRequestAssetViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
}

protocol ReceiveAndRequestAssetInteractorInput: AnyObject {
    func setup(with output: ReceiveAndRequestAssetInteractorOutput)
}

final class ReceiveAndRequestAssetPresenter {
    enum Constants {
        static let qrSize = CGSize(width: 240, height: 240)
    }

    // MARK: Private properties

    private weak var view: ReceiveAndRequestAssetViewInput?
    private let router: ReceiveAndRequestAssetRouterInput
    private let interactor: ReceiveAndRequestAssetInteractorInput

    private let wallet: MetaAccountModel
    private var chainAsset: ChainAsset
    private let qrService: QRServiceProtocol
    private let sharingFactory: AccountShareFactoryProtocol

    private var qrOperation: Operation?
    private var inputResult: AmountInputResult?
    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var pricesData: [PriceData]? = []

    private var address: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        qrService: QRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        interactor: ReceiveAndRequestAssetInteractorInput,
        router: ReceiveAndRequestAssetRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let address = address else {
            assertionFailure()
            return
        }

        view?.didReceive(viewModel: ReceiveAssetViewModel(
            asset: chainAsset.asset.symbolUppercased,
            accountName: wallet.name,
            address: address,
            isSora: chainAsset.chain.isSora
        ))
    }

    private func provideAssetVewModel() {
        let balance = getBalance()
        let inputAmount = inputResult?.absoluteValue(from: balance) ?? 0.0
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, chainAsset: chainAsset)

        let priceData = pricesData?.first(where: { $0.priceId == chainAsset.asset.priceId })

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceive(assetBalanceViewModel: viewModel)
    }

    func provideInputViewModel() {
        let balance = getBalance()
        let inputAmount = inputResult?.absoluteValue(from: balance)

        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, chainAsset: chainAsset)
        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func getBalance() -> Decimal {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return .zero
        }
        let key = chainAsset.uniqueKey(accountId: accountId)
        guard let accountInfo = accountInfos[key] else {
            return .zero
        }
        let balance = accountInfo.map {
            Decimal.fromSubstrateAmount(
                $0.data.sendAvailable,
                precision: Int16(chainAsset.asset.precision)
            ) ?? .zero
        } ?? .zero
        return balance
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> BalanceViewModelFactoryProtocol {
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func generateQR() {
        cancelQRGeneration()

        guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()), let address = account.toAddress() else {
            processOperation(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }
        var qrType: QRType = .address(address)
        if chainAsset.chain.isSora {
            let balance = getBalance()
            var inputAmount = inputResult?.absoluteValue(from: balance).stringWithPointSeparator
            if
                chainAsset.asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId,
                var input = inputResult?.absoluteValue(from: balance) {
                var drounded = Decimal()
                NSDecimalRound(&drounded, &input, 2, .plain)
                inputAmount = input.stringWithPointSeparator
            }
            let addressInfo = SoraQRInfo(
                prefix: SubstrateQRConstants.prefix,
                address: address,
                rawPublicKey: account.publicKey,
                username: wallet.name,
                assetId: chainAsset.asset.currencyId ?? "",
                amount: inputAmount
            )
            qrType = .addressInfo(addressInfo)
        }
        do {
            qrOperation = try qrService.generate(
                with: qrType,
                qrSize: Constants.qrSize,
                runIn: .main
            ) { [weak self] operationResult in
                if let result = operationResult {
                    self?.qrOperation = nil
                    self?.processOperation(result: result)
                }
            }
        } catch {
            processOperation(result: .failure(error))
        }
    }

    private func cancelQRGeneration() {
        qrOperation?.cancel()
        qrOperation = nil
    }

    private func processOperation(result: Result<UIImage, Error>) {
        switch result {
        case let .success(image):
            view?.didReceive(image: image)
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - ReceiveAndRequestAssetViewOutput

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetViewOutput {
    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            selectedAssetId: chainAsset.asset.id,
            chainAssets: chainAsset.chain.chainAssets,
            output: self
        )
    }

    func didLoad(view: ReceiveAndRequestAssetViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        generateQR()
        if chainAsset.chain.isSora {
            provideAssetVewModel()
            provideInputViewModel()
        } else {
            view.didReceive(assetBalanceViewModel: nil)
        }
    }

    func share(qrImage: UIImage) {
        guard let address = address else {
            assertionFailure()
            return
        }

        let sources = sharingFactory.createSources(
            accountAddress: address,
            qrImage: qrImage,
            assetSymbol: chainAsset.asset.symbolUppercased,
            chainName: chainAsset.chain.name,
            locale: selectedLocale
        )

        router.share(sources: sources, from: view, with: nil)
    }

    func close() {
        router.dismiss(view: view)
    }

    func presentAccountOptions() {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress(), let view = view else {
            return
        }

        router.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAssetVewModel()
        generateQR()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()
        generateQR()
    }
}

// MARK: - ReceiveAndRequestAssetInteractorOutput

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetInteractorOutput {
    func didReceivePricesData(result: Result<[SSFModels.PriceData], Error>) {
        switch result {
        case let .success(prices):
            pricesData = prices
            provideAssetVewModel()
        case let .failure(failure):
            Logger.shared.customError(failure)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: SSFModels.ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfos[key] = accountInfo
            if self.chainAsset == chainAsset {
                provideAssetVewModel()
                provideInputViewModel()
            }
        case let .failure(failure):
            Logger.shared.customError(failure)
        }
    }
}

// MARK: - Localizable

extension ReceiveAndRequestAssetPresenter: Localizable {
    func applyLocalization() {}
}

extension ReceiveAndRequestAssetPresenter: ReceiveAndRequestAssetModuleInput {}

extension ReceiveAndRequestAssetPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: SSFModels.ChainAsset?, contextTag _: Int?) {
        guard let chainAsset = chainAsset else {
            return
        }
        self.chainAsset = chainAsset

        provideViewModel()
        provideAssetVewModel()
        provideInputViewModel()
        generateQR()
    }
}
