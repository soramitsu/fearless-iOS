import Foundation
import SoraUI

/**
 *  Subclass of `BackgroundedContentControl` designed to provide button that contains
 *  triangulared background with shadows and content view consisting of title and icon.
 *
 *  Class supports `IBDesignable` protocol to provide appearance via Interface Builder.
 */
@IBDesignable
class TriangularedButton: BackgroundedContentControl {
    /// Returns content view that consists of title and icon
    public var imageWithTitleView: ImageWithTitleView? {
        contentView as? ImageWithTitleView
    }

    /// Returns backround view with cut corners
    var triangularedView: TriangularedView? {
        self.backgroundView as? TriangularedView
    }

    // MARK: Overriden initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    /**
         Creates and setups content and background views. This method **must not** be called
         directly but can be overriden by subclass.
     */
    open func configure() {
        backgroundColor = UIColor.clear

        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView?.isUserInteractionEnabled = false
        }

        if contentView == nil {
            contentView = ImageWithTitleView()
            contentView?.isUserInteractionEnabled = false
        }
    }
}
