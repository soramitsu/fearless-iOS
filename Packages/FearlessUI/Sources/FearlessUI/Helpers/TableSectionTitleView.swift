/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public class TableSectionTitleView: UIView {

    struct Style: StyleProtocol {
        let font: UIFont
        let color: UIColor
        let insets: UIEdgeInsets
    }

    private static let defaultStyle = TableSectionTitleView.Style(font: .systemFont(ofSize: 15, weight: .semibold),
                                                           color: .black,
                                                           insets: .init(top: 16,
                                                                         left: 16,
                                                                         bottom: 16,
                                                                         right: 16))

    let titleLabel: UILabel

    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
        }
    }

    init() {
        titleLabel = UILabel()
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        addSubview(titleLabel)
        apply(style: TableSectionTitleView.defaultStyle)
    }

    private func apply(style: TableSectionTitleView.Style) {
        titleLabel.font = style.font
        titleLabel.textColor = style.color
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: style.insets.top).isActive = true
        titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -style.insets.top).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -style.insets.top).isActive = true
        titleLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: style.insets.top).isActive = true
    }

}

extension TableSectionTitleView: StyleApplicable {
    public func apply(style: StyleProtocol) {
        if let style = style as? Style {
            apply(style: style)
        }
    }
}
