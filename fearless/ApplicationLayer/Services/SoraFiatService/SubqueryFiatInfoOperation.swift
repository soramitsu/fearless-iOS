import RobinHood
import sorawallet
import Foundation

public final class SubqueryFiatInfoOperation<ResultType>: BaseOperation<ResultType> {
    private let httpProvider: SoramitsuHttpClientProviderImpl
    private let soraNetworkClient: SoramitsuNetworkClient
    private let subQueryClient: SoraWalletBlockExplorerInfo
    private let baseUrl: URL

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        httpProvider = SoramitsuHttpClientProviderImpl()
        soraNetworkClient = SoramitsuNetworkClient(timeout: 60000, logging: true, provider: httpProvider)
        let provider = SoraRemoteConfigProvider(
            client: soraNetworkClient,
            commonUrl: "https://config.polkaswap2.io/prod/common.json",
            mobileUrl: "https://config.polkaswap2.io/prod/mobile.json"
        )
        let configBuilder = provider.provide()

        subQueryClient = SoraWalletBlockExplorerInfo(networkClient: soraNetworkClient, soraRemoteConfigBuilder: configBuilder)

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        var optionalCallResult: Result<ResultType, Swift.Error>?

        DispatchQueue.main.async {
            self.subQueryClient.getFiat(completionHandler: { [self] requestResult, _ in

                if let data = requestResult as? ResultType {
                    optionalCallResult = .success(data)
                }

                semaphore.signal()

                result = optionalCallResult
            })
        }

        semaphore.wait()
    }
}
