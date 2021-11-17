import Foundation

final class ChainLocalRepository {
    enum Constants {
        static let githubChainListUrl: String = "https://raw.githubusercontent.com/soramitsu/fearless-utils/feature/externalapi/chains/chains.json"
    }

    private let utilsLocalRepository: UtilsLocalRepository<[ChainModel]>

    init?(logger: LoggerProtocol?) {
        guard let url = URL(string: Constants.githubChainListUrl) else {
            return nil
        }

        utilsLocalRepository = UtilsLocalRepository(
            url: url,
            logger: logger
        )
    }

    func getSubqueryHistoryUrl(assetId: WalletAssetId) -> URL? {
        let chains = utilsLocalRepository.fetch()

        let urlString = chains?
            .first { assetId.titleForLocale(Locale.current) == $0.name }?.externalApi?.history.url

        guard let urlString = urlString, let url = URL(string: urlString) else {
            return assetId.subqueryHistoryUrl
        }

        return url
    }
}
