/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
 *  Subclass of `BackgroundedContentControl` designed to provide button that contains
 *  rounded background with shadows and content view consisting of title and icon.
 *
 *  Class supports `IBDesignable` protocol to provide appearance via Interface Builder.
 */
@IBDesignable
open class RoundedButton: BackgroundedContentControl {
    /// Returns content view that consists of title and icon
    public var imageWithTitleView: ImageWithTitleView? {
        return self.contentView as? ImageWithTitleView
    }

    /// Returns backround view with rounded corners
    public var roundedBackgroundView: RoundedView? {
        return self.backgroundView as? RoundedView
    }

    // MARK: Overriden initializers

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    /**
        Creates and setups content and background views. This method **must not** be called
        directly but can be overriden by subclass.
    */
    open func configure() {
        self.backgroundColor = UIColor.clear

        if self.backgroundView == nil {
            self.backgroundView = RoundedView()
            self.backgroundView?.isUserInteractionEnabled = false
        }

        if self.contentView == nil {
            self.contentView = ImageWithTitleView()
            self.contentView?.isUserInteractionEnabled = false
        }
    }
}
