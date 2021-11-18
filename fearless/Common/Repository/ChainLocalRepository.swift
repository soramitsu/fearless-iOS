import Foundation
import RobinHood

typealias ChainModelList = [ChainModel]

extension ChainModelList: Identifiable {
    public var identifier: String {
        "ChainModelList"
    }
}

final class ChainLocalRepository {
    enum Constants {
        static let githubChainListUrl: String = "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/chains/chains.json"
    }

    private let utilsLocalRepository: UtilsLocalRepository<ChainModelList>

    init?(logger: LoggerProtocol?) {
        guard let url = URL(string: Constants.githubChainListUrl) else {
            return nil
        }
        let databaseRepository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            SubstrateDataStorageFacade.shared.createRepository()
        utilsLocalRepository = UtilsLocalRepository(
            url: url,
            logger: logger,
            repository: AnyDataProviderRepository(databaseRepository)
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
