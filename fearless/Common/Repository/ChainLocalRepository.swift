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
        static let githubChainListUrl: URL? =
            URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/chains/chains.json")
    }

    private let utilsLocalRepository: UtilsLocalRepository<ChainModelList>

    init?(logger: LoggerProtocol?) {
        guard let url = Constants.githubChainListUrl else {
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

        guard let url = chains?
                .first(where: { assetId.titleForLocale(Locale.current) == $0.name })?.externalApi?.history.url else {
            return assetId.subqueryHistoryUrl
        }

        return url
    }
}
