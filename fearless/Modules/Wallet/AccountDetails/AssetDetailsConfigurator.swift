import Foundation
import CommonWallet

final class AssetDetailsConfigurator {
    func configure(builder: AccountDetailsModuleBuilderProtocol) {
        let containingViewFactory = AssetDetailsContainingViewFactory()
        builder.with(containingViewFactory: containingViewFactory)
    }
}
