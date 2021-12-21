import Foundation

protocol ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chainAsset: ChainAsset) -> [ChainOptionsViewModel]?
}

extension ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chainAsset: ChainAsset) -> [ChainOptionsViewModel]? {
        let presentableOptions = [ChainOptions.testnet]

        var viewModels: [ChainOptionsViewModel] = []

        if chainAsset.chain.name != nil {
            let chainNameOptionViewModel = ChainOptionsViewModel(
                text: chainAsset.chain.name,
                icon: RemoteImageViewModel(url: chainAsset.chain.icon)
            )
            viewModels.append(chainNameOptionViewModel)
        }

        if let options = chainAsset.chain.options {
            let chainOptionsViewModels = options
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
