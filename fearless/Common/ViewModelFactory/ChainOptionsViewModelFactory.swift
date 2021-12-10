import Foundation

protocol ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chain: ChainModel, asset: AssetModel) -> [ChainOptionsViewModel]?
}

extension ChainOptionsViewModelFactoryProtocol {
    func buildChainOptionsViewModel(chain: ChainModel, asset: AssetModel) -> [ChainOptionsViewModel]? {
        let presentableOptions = [ChainOptions.testnet]

        var viewModels: [ChainOptionsViewModel] = []

        if asset.name != nil {
            let chainNameOptionViewModel = ChainOptionsViewModel(
                text: chain.name,
                icon: RemoteImageViewModel(url: chain.icon)
            )
            viewModels.append(chainNameOptionViewModel)
        }

        if let options = chain.options {
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
