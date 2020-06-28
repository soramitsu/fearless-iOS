import UIKit
import SoraUI

final class FearlessLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(frame: UIScreen.main.bounds,
                                      indicatorImage: R.image.iconLoadingIndicator() ?? UIImage())
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.19)
        loadingView.contentBackgroundColor = UIColor.white
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
