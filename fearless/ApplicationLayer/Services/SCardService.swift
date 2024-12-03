import SCard
import SoraFoundation
import SoraUIKit
import SSFCrypto
import SSFModels

final class SCardService {
    private let wallet: MetaAccountModel
    private let soraChainAsset: ChainAsset

    var onReceiveController: ((UIViewController) -> Void)?
    var onSwapController: ((UIViewController) -> Void)?

    init(
        wallet: MetaAccountModel,
        soraChainAsset: ChainAsset
    ) {
        self.wallet = wallet
        self.soraChainAsset = soraChainAsset
    }

    func initSoraCard() -> SCard {
        guard SCard.shared == nil else {
            return SCard.shared!
        }

        let addressProvider: () -> String = { [weak self] in
            guard let self,
                  let accountId = self.wallet.fetch(for: self.soraChainAsset.chain.accountRequest())?.accountId else { return "" }

            let address = try? AddressFactory.address(
                for: accountId,
                chain: self.soraChainAsset.chain
            )
            return address ?? ""
        }
        
        let config = SCard.Config.local

        let xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))

        let soraCard = SCard(
            addressProvider: addressProvider,
            config: config,
//            balanceStream: xorBalanceStream,
            onReceiveController: { [weak self] vc in
                self?.onReceiveController?(vc)
            },
            onSwapController: { [weak self] vc in
                self?.onSwapController?(vc)
            }
        )

        SCard.shared = soraCard

        LocalizationManager.shared.addObserver(with: soraCard) { [weak soraCard] _, newLocalization in
            soraCard?.selectedLocalization = newLocalization
        }

        return soraCard
    }
}

extension SCard.Config {
//    static let local = SCard.Config(
//        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
//        backendUrl: "https://backend.dev.sora-card.tachi.soramitsu.co.jp/",
//        pwAuthDomain: "soracard.com",
//        pwApiKey: "6974528a-ee11-4509-b549-a8d02c1aec0d",
//        appPlatformId: "6974528a-ee11-4509-b549-a8d02c1aec0d",
//        recaptchaKey: "FB0F27BD-E525-4876-A17E-A63B4C33B293",
//        kycUrl: "https://kyc-test.soracard.com/mobile",
//        kycUsername: "E7A6CB83-630E-4D24-88C5-18AAF96032A4",
//        kycPassword: "75A55B7E-A18F-4498-9092-58C7D6BDB333",
//        xOneEndpoint: "https://dev.x1ex.com/widgets/sdk.js",
//        xOneId: "sprkwdgt-WYL6QBNC",
//        environmentType: .test,
//        themeMode: SoramitsuUI.shared.themeMode
//    )
//    
    static let local = SCard.Config(
        appStoreUrl: "https://apps.apple.com/us/app/sora-wallet-polkaswap/id1457566711",
        backendUrl: "https://backend.dev.sora-card.tachi.soramitsu.co.jp/",
        pwAuthDomain: "soracard.com",
        pwApiKey: "6974528a-ee11-4509-b549-a8d02c1aec0d",
        appPlatformId: "cb281534-52b9-49fc-bba5-41f241e24592",
        recaptchaKey: "6LeWLPEpAAAAADUgxnZD50V3GvmFLGKhVTLVMxSV",
        kycUrl: "https://kyc-test.soracard.com/mobile",
        kycUsername: "E7A6CB83-630E-4D24-88C5-18AAF96032A4",
        kycPassword: "75A55B7E-A18F-4498-9092-58C7D6BDB333",
        xOneEndpoint: "https://dev.x1ex.com/widgets/sdk.js",
        xOneId: "sprkwdgt-WYL6QBNC",
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )
}
