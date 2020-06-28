import Foundation
import SoraUI

final class FearlessLoadingViewPresenter: LoadingViewPresenter {
    static let shared = FearlessLoadingViewPresenter(factory: FearlessLoadingViewFactory.self)

    override private init(factory: LoadingViewFactoryProtocol.Type) {
        super.init(factory: factory)
    }
}
