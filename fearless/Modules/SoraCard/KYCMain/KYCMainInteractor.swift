import UIKit
import RobinHood
import Foundation
import FearlessUtils

enum KYCConstants {
    static let requiredAmountOfEuro = 100
    static let minAmountOfEuroProcentage: Float = 0.95
}

enum FreeAttemptBalanceState {
    case hasEnough
    case missingBalance(xor: Decimal, fiat: Decimal)
}

struct KYCMainData {
    let percentage: Float
    let hasFreeAttempts: Bool
    let freeAttemptBalanceState: FreeAttemptBalanceState
}

final class KYCMainInteractor {
    // MARK: - Private properties

    private let data: SCKYCUserDataModel

    private weak var output: KYCMainInteractorOutput?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let service: SCKYCService
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoFetching: AccountInfoFetchingProtocol
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var xorPrice: PriceData?
    private var chainAssetsAccountInfo: [ChainAsset: AccountInfo?] = [:]
    private var kycAttempts: SCKYCAtempts?
    private var xorChainAssets: [ChainAsset] = []
    private let eventCenter = EventCenter.shared
    let wallet: MetaAccountModel

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    init(
        data: SCKYCUserDataModel,
        wallet: MetaAccountModel,
        service: SCKYCService,
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoFetching: AccountInfoFetchingProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.data = data
        self.wallet = wallet
        self.service = service
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoFetching = accountInfoFetching
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory

        eventCenter.add(observer: self)
    }
}

// MARK: - KYCMainInteractorInput

extension KYCMainInteractor: KYCMainInteractorInput {
    func setup(with output: KYCMainInteractorOutput) {
        self.output = output
        checkKycAttempts()
    }

    func prepareToDismiss() {
        priceProvider?.removeObserver(self)
    }
}

private extension KYCMainInteractor {
    func checkKycAttempts() {
        Task {
            switch await service.kycAttempts() {
            case .failure: ()
            case let .success(kycAttempts):
                self.kycAttempts = kycAttempts
            }
            await MainActor.run(body: { [weak self] in
                self?.getSoraChainAsset()
            })
        }
    }

    func getSoraChainAsset() {
        chainAssetFetching.fetch(
            filters: [.assetName("XOR")],
            sortDescriptors: []
        ) { [weak self] result in
            guard let strongSelf = self,
                  let result = result,
                  case let .success(chainAssets) = result
            else {
                return
            }
            #if DEBUG
                strongSelf.xorChainAssets = chainAssets
            #else
                strongSelf.xorChainAssets = chainAssets.filter { chainAsset in
                    chainAsset.chain.chainId == Chain.soraMain.genesisHash
                }
            #endif
            strongSelf.output?.didReceive(xorChainAssets: chainAssets)
            strongSelf.getXorBalance(for: strongSelf.xorChainAssets)
            strongSelf.subscribeToPrice(for: strongSelf.xorChainAssets.first)
        }
    }

    func getXorBalance(for chainAssets: [ChainAsset]) {
        accountInfoFetching.fetch(for: chainAssets, wallet: wallet) { [weak self] chainAssetsAccInfo in
            guard let strongSelf = self else { return }
            strongSelf.chainAssetsAccountInfo = chainAssetsAccInfo
            self?.checkEnoughtAmount()
        }
    }

    func subscribeToPrice(for chainAsset: ChainAsset?) {
        priceProvider?.removeObserver(self)
        if let priceId = chainAsset?.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func checkEnoughtAmount() {
        guard let priceData = xorPrice else {
            return
        }
        let balance: Decimal = xorChainAssets.compactMap { chainAsset in
            let assetInfo = chainAsset.asset.displayInfo
            guard let accountInfoKeyValue = chainAssetsAccountInfo[chainAsset],
                  let accountInfo = accountInfoKeyValue else { return Decimal.zero }
            return Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: assetInfo.assetPrecision
            )
        }.max() ?? Decimal.zero

        let price = priceData.price
        guard let priceDecimal = Decimal(string: price) else { return }

        let fiatBalance = priceDecimal * balance

        let requiredAmountOfXORInEuro = Decimal(KYCConstants.requiredAmountOfEuro) // 95€
        let requiredAmountOfXOR = requiredAmountOfXORInEuro / priceDecimal

        let percentage = (min(1, fiatBalance / requiredAmountOfXORInEuro) as NSNumber).floatValue
        let missingBalance = requiredAmountOfXOR - balance
        let missingFiatBalance = requiredAmountOfXORInEuro - fiatBalance

        let isKYCFree = kycAttempts?.hasFreeAttempts ?? true // TODO: SC fix logic on Phase 2

        let hasEnoughXor = percentage >= KYCConstants.minAmountOfEuroProcentage

        let balanceState: FreeAttemptBalanceState = hasEnoughXor ? .hasEnough : .missingBalance(xor: missingBalance, fiat: missingFiatBalance)
        let receivedData = KYCMainData(
            percentage: percentage,
            hasFreeAttempts: isKYCFree,
            freeAttemptBalanceState: balanceState
        )
        output?.didReceive(data: receivedData)
    }
}

extension KYCMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        if case let .success(price) = result {
            self.xorPrice = price
            checkEnoughtAmount()
        }
    }
}

extension KYCMainInteractor: EventVisitorProtocol {
    func processKYCReceivedFinalStatus() {
        output?.didReceiveFinalStatus()
    }
}
