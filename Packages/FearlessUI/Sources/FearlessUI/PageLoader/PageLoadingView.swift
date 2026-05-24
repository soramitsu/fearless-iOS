/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

open class PageLoadingView: UIView {
    public private(set) var activityIndicatorView: UIActivityIndicatorView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    open var verticalMargin: CGFloat = 8.0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override open var intrinsicContentSize: CGSize {
        var size = activityIndicatorView.intrinsicContentSize
        size.height += 2.0 * verticalMargin

        return size
    }

    private func configure() {
        activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(activityIndicatorView)

        activityIndicatorView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        activityIndicatorView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }

    open func start() {
        activityIndicatorView.startAnimating()
    }

    open func stop() {
        activityIndicatorView.stopAnimating()
    }
}
