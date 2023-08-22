import SCard
import SoraFoundation
import RobinHood
import SSFModels
import SoraUIKit

final class SoraCardInitializer {
    private let wallet: MetaAccountModel
    private let soraChainAsset: ChainAsset
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
    var onSwapHandler: ((UIViewController) -> Void)?

    init(
        wallet: MetaAccountModel,
        soraChainAsset: ChainAsset,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
    ) {
        self.wallet = wallet
        self.soraChainAsset = soraChainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
    }

    func initSoraCard() -> SCard {
        guard SCard.shared == nil else { return SCard.shared! }

        let addressProvider: () -> String = { [weak self] in
            guard let strongSelf = self,
                  let accountId = strongSelf.wallet.fetch(for: strongSelf.soraChainAsset.chain.accountRequest())?.accountId else { return "" }

            let address = try? AddressFactory.address(
                for: accountId,
                chain: strongSelf.soraChainAsset.chain
            )
            return address ?? ""
        }

        let xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))

        let soraCard = SCard(
            addressProvider: addressProvider,
            config: .local,
            balanceStream: xorBalanceStream,
            onSwapController: { [weak self] vc in
                self?.onSwapHandler?(vc)
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
    static let prod = SCard.Config(
        backendUrl: SoraCardCIKeys.backendProdUrl,
        pwAuthDomain: SoraCardCIKeys.domainProd,
        pwApiKey: SoraCardCIKeys.apiKeyProd,
        kycUrl: SoraCardCIKeys.kycEndpointUrlProd,
        kycUsername: SoraCardCIKeys.kycUsernameProd,
        kycPassword: SoraCardCIKeys.kycPasswordProd,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointProd,
        xOneId: SoraCardCIKeys.xOneIdProd,
        environmentType: .prod,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let test = SCard.Config(
        backendUrl: SoraCardCIKeys.backendTestUrl,
        pwAuthDomain: SoraCardCIKeys.domainTest,
        pwApiKey: SoraCardCIKeys.apiKeyTest,
        kycUrl: SoraCardCIKeys.kycEndpointUrlTest,
        kycUsername: SoraCardCIKeys.kycUsernameTest,
        kycPassword: SoraCardCIKeys.kycPasswordTest,
        xOneEndpoint: SoraCardCIKeys.xOneEndpointTest,
        xOneId: SoraCardCIKeys.xOneIdTest,
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )

    static let local = SCard.Config(
        backendUrl: "https://backend.dev.sora-card.tachi.soramitsu.co.jp/",
        pwAuthDomain: "soracard.com",
        pwApiKey: "6974528a-ee11-4509-b549-a8d02c1aec0d",
        kycUrl: "https://kyc-test.soracard.com/mobile",
        kycUsername: "E7A6CB83-630E-4D24-88C5-18AAF96032A4",
        kycPassword: "75A55B7E-A18F-4498-9092-58C7D6BDB333",
        xOneEndpoint: "https://dev.x1ex.com/widgets/sdk.js",
        xOneId: "sprkwdgt-WYL6QBNC",
        environmentType: .test,
        themeMode: SoramitsuUI.shared.themeMode
    )
}
