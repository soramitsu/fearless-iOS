/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public final class EmptyStateCollectionViewCell: UICollectionViewCell {

    public private(set) var viewModel: EmptyStateListViewModelProtocol?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
    }

    public func bind(viewModel: EmptyStateListViewModelProtocol) {
        self.viewModel?.emptyStateView.removeFromSuperview()
        self.viewModel = viewModel
        contentView.addSubview(viewModel.emptyStateView)

        setNeedsLayout()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        guard let viewModel = self.viewModel else {
            return
        }

        let insets = viewModel.displayInsetsForEmptyState
        viewModel.emptyStateView.frame = contentView.bounds.inset(by: insets)
    }
}
