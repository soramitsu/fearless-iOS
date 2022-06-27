import Foundation

protocol ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chainAsset: ChainAsset) -> [ChainOptionsViewModel]?
}

extension ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chainAsset: ChainAsset) -> [ChainOptionsViewModel]? {
        let presentableOptions = [ChainOptions.testnet]

        var viewModels: [ChainOptionsViewModel] = []

        if chainAsset.chain.chainId != chainAsset.asset.chainId {
            let chainNameOptionViewModel = ChainOptionsViewModel(
                text: chainAsset.chain.name,
                icon: chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) }
            )
            viewModels.append(chainNameOptionViewModel)
        }

        if chainAsset.chain.options.isNotEmpty {
            let chainOptionsViewModels = chainAsset.chain.options
                .filter { presentableOptions.contains($0) }
                .compactMap { option -> ChainOptionsViewModel in
                    let icon = option == .testnet ? R.image.iconTestnet() : nil
                    return ChainOptionsViewModel(
                        text: option.rawValue,
                        icon: BundleImageViewModel(image: icon)
                    )
                }

            viewModels.append(contentsOf: chainOptionsViewModels)
        }

        return viewModels
    }
}
