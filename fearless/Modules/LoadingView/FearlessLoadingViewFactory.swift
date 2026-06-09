import UIKit
import FearlessUI

final class FearlessLoadingViewFactory: LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView {
        let icon = R.image.iconLoadingIndicator()?.tinted(with: R.color.colorWhite()!)
        return createLoadingView(indicatorImage: icon)
    }

    static func createLoadingView(indicatorImage: UIImage?) -> LoadingView {
        let loadingView = LoadingView(
            frame: UIScreen.main.bounds,
            indicatorImage: indicatorImage ?? UIImage()
        )
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.19)
        loadingView.contentBackgroundColor = UIColor.black.withAlphaComponent(0.04)
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        return loadingView
    }
}
