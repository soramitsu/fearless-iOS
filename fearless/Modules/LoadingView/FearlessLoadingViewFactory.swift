import UIKit
import SoraUI

final class FearlessLoadingViewFactory: LoadingViewFactoryProtocol {
    /// The app's own full-page loader. Kit v4: the mirror loader's three comets (96 pt) take the spinning icon's place;
    /// the rest of the loader (its dim, its content box, its show and hide) is unchanged.
    static func createLoadingView() -> LoadingView {
        let loadingView = LoadingView(
            frame: UIScreen.main.bounds,
            indicatorImage: UIImage()
        )
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.19)
        loadingView.contentBackgroundColor = UIColor.black.withAlphaComponent(0.04)
        loadingView.contentSize = CGSize(width: 120.0, height: 120.0)
        loadingView.animationDuration = 1.0
        addMirrorLoader(to: loadingView)
        return loadingView
    }
}
