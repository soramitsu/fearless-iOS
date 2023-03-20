import Foundation

protocol PoolRolesConfirmViewModelFactoryProtocol {
    func buildViewModel(
        roles: StakingPoolRoles,
        accounts: [MetaAccountModel]?
    ) -> PoolRolesConfirmViewModel
}

final class PoolRolesConfirmViewModelFactory: PoolRolesConfirmViewModelFactoryProtocol {
    private let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    func buildViewModel(
        roles: StakingPoolRoles,
        accounts: [MetaAccountModel]?
    ) -> PoolRolesConfirmViewModel {
        let rootAddress = try? roles.root?.toAddress(using: chainAsset.chain.chainFormat)
        let nominatorAddress = try? roles.nominator?.toAddress(using: chainAsset.chain.chainFormat)
        let bouncerAddress = try? roles.bouncer?.toAddress(using: chainAsset.chain.chainFormat)

        let rootAccount = accounts?.first(where: {
            $0.fetch(for: chainAsset.chain.accountRequest())?.toAddress() == rootAddress
        })
        let nominatorAccount = accounts?.first(where: {
            $0.fetch(for: chainAsset.chain.accountRequest())?.toAddress() == nominatorAddress
        })
        let bouncerAccount = accounts?.first(where: {
            $0.fetch(for: chainAsset.chain.accountRequest())?.toAddress() == bouncerAddress
        })

        let rootTitle = rootAccount != nil ? rootAccount?.name : rootAddress
        let rootSubtitle = rootAccount != nil ? rootAddress : nil

        let nominatorTitle = nominatorAccount != nil ? nominatorAccount?.name : nominatorAddress
        let nominatorSubtitle = nominatorAccount != nil ? nominatorAddress : nil

        let bouncerTitle = bouncerAccount != nil ? bouncerAccount?.name : bouncerAddress
        let bouncerSubtitle = bouncerAccount != nil ? bouncerAddress : nil

        let rootViewModel = TitleMultiValueViewModel(
            title: rootTitle,
            subtitle: rootSubtitle
        )
        let nominatorViewModel = TitleMultiValueViewModel(
            title: nominatorTitle,
            subtitle: nominatorSubtitle
        )
        let bouncerViewModel = TitleMultiValueViewModel(
            title: bouncerTitle,
            subtitle: bouncerSubtitle
        )

        return PoolRolesConfirmViewModel(
            rootViewModel: rootViewModel,
            nominatorViewModel: nominatorViewModel,
            bouncerViewModel: bouncerViewModel
        )
    }
}
