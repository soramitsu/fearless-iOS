import UIKit
import SoraFoundation

final class SCXOneAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset) -> SCXOneModuleCreationResult? {
        let interactor = SCXOneInteractor(service: .shared)
        let router = SCXOneRouter()

        let presenter = SCXOnePresenter(
            interactor: interactor,
            router: router,
            wallet: wallet,
            chainAsset: chainAsset
        )

        let view = SCXOneViewController(
            output: presenter
        )

        return (view, presenter)
    }
}
