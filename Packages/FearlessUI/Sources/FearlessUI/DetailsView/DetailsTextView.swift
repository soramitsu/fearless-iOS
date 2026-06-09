import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DetailsTextViewDelegate: AnyObject {
    func didChangeExpandingState(in detailsView: DetailsTextView)
}

@IBDesignable
open class DetailsTextView: UIView {
    @IBInspectable
    open var expanded: Bool = false {
        didSet {
            updateExpansionState()
        }
    }

    @IBInspectable
    open var textColor: UIColor {
        set {
            textLabel.textColor = newValue
        }

        get {
            return textLabel.textColor
        }
    }

    open var textFont: UIFont {
        set {
            textLabel.font = newValue
            invalidateIntrinsicContentSize()
        }

        get {
            return textLabel.font
        }
    }

    @IBInspectable
    open var text: String? {
        set {
            textLabel.text = newValue
            invalidateIntrinsicContentSize()
        }

        get {
            return textLabel.text
        }
    }

    @IBInspectable
    open var collapsedActionTitle: String = "Show more" {
        didSet {
            updateActionButton()
        }
    }

    @IBInspectable
    open var expandedActionTitle: String = "Show less" {
        didSet {
            updateActionButton()
        }
    }

    @IBInspectable
    open var actionTitleColor: UIColor? {
        set {
            actionButton.setTitleColor(newValue, for: .normal)
        }

        get {
            return actionButton.titleColor(for: .normal)
        }
    }

    open var actionTitleFont: UIFont? {
        set {
            actionButton.titleLabel?.font = newValue
        }

        get {
            return actionButton.titleLabel?.font
        }
    }

    @IBInspectable
    open var gradientStartColor: UIColor {
        set {
            gradientView.startColor = newValue
        }

        get {
            return gradientView.startColor
        }
    }

    @IBInspectable
    open var gradientEndColor: UIColor {
        set {
            gradientView.endColor = newValue
        }

        get {
            return gradientView.endColor
        }
    }

    @IBInspectable
    open var gradientTransitionLocation: Float {
        set {
            gradientView.transitionLocation = newValue
        }

        get {
            return gradientView.transitionLocation
        }
    }

    @IBInspectable
    open var footerHeight: CGFloat = 44.0 {
        didSet {
            footerHeightConstraint.constant = footerHeight
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    @IBInspectable
    open var showsFooter: Bool {
        set {
            footerView.isHidden = !newValue
        }

        get {
            return !footerView.isHidden
        }
    }

    weak public var delegate: DetailsTextViewDelegate?

    private var textLabel: UILabel!
    private var actionButton: UIButton!
    private var footerView: UIView!
    private var footerHeightConstraint: NSLayoutConstraint!
    private var gradientView: GradientView!

    // MARK: Configure

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        if textLabel == nil {
            configure()
        }
    }

    private func configure() {
        backgroundColor = .clear
        clipsToBounds = true

        configureTextLabel()
        configureFooterView()
    }

    private func configureTextLabel() {
        textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.backgroundColor = .clear
        textLabel.numberOfLines = 0
        addSubview(textLabel)

        textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0.0).isActive = true
        textLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: 0.0).isActive = true
        textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0.0).isActive = true
    }

    private func configureFooterView() {
        footerView = UIView()
        footerView.backgroundColor = .clear
        footerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(footerView)

        footerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0.0).isActive = true
        footerView.rightAnchor.constraint(equalTo: rightAnchor, constant: 0.0).isActive = true
        footerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0.0).isActive = true
        footerHeightConstraint = footerView.heightAnchor.constraint(equalToConstant: footerHeight)
        footerHeightConstraint.isActive = true

        configureGradienView()
        configureActionButton()
    }

    private func configureActionButton() {
        actionButton = UIButton(type: .system)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(actionButton)

        actionButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 0.0).isActive = true
        actionButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor, constant: 0.0).isActive = true

        actionButton.addTarget(self,
                               action: #selector(actionButtonPressed(_:)),
                               for: .touchUpInside)

        updateActionButton()
    }

    private func configureGradienView() {
        gradientView = GradientView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientView.endPoint = CGPoint(x: 0.5, y: 0.0)
        footerView.addSubview(gradientView)

        gradientView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 0.0).isActive = true
        gradientView.rightAnchor.constraint(equalTo: footerView.rightAnchor, constant: 0.0).isActive = true
        gradientView.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 0.0).isActive = true
        gradientView.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: 0.0).isActive = true
    }

    // MARK: Update

    func updateExpansionState() {
        updateActionButton()
    }

    func updateActionButton() {
        let title = expanded ? expandedActionTitle : collapsedActionTitle
        actionButton.setTitle(title, for: .normal)
    }

    // MARK: Action

    @objc func actionButtonPressed(_ sender: AnyObject?) {
        expanded = !expanded
        delegate?.didChangeExpandingState(in: self)
    }
}
