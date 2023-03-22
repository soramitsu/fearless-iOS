//
//  SoramitsuButton.swift
//  SoraSwiftUI
//
//  Created by Ivan Shlyapkin on 14.09.2022.
//

import Foundation
import UIKit

public final class SoramitsuButton: UIControl, Molecule {

    public let sora: SoramitsuButtonConfiguration<SoramitsuButton>

    // MARK: - UI
    
    var horizontalConstaint: NSLayoutConstraint?
    var leftImageSizeConstaint: NSLayoutConstraint?
    var rightImageSizeConstaint: NSLayoutConstraint?

    let leftImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.isHidden = true
        label.sora.alignment = .center
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    public let rightImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    let pressingView: SoramitsuView = {
        let view = SoramitsuView()
        view.alpha = 0
        return view
    }()

    private var shapePath: UIBezierPath {
        return UIBezierPath(rect: self.bounds)
    }

    private var size: SoramitsuButtonSize = .large

    private var type: SoramitsuButtonType = .filled(.primary)

    init(style: SoramitsuStyle, size: SoramitsuButtonSize, type: SoramitsuButtonType = .filled(.primary)) {
        sora = SoramitsuButtonConfiguration(style: style)
        self.size = size
        self.type = type
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        guard case .bleached = type else { return }
        applyShadowPath()
    }

    public override var isEnabled: Bool {
        didSet {
            updateView()
        }
    }

    func pressedAnimation() {
        UIView.animate(withDuration: 0.3,
                      delay: .zero,
                      options: [.allowUserInteraction, .curveEaseInOut],
                      animations: {
            self.pressingView.sora.alpha = 1
        }) { completed in
            UIView.animate(withDuration: 0.3,
                          delay: .zero,
                          options: [.allowUserInteraction, .curveEaseInOut],
                          animations: {
                self.pressingView.sora.alpha = 0
            })
        }
    }

    func updateView() {
        if case .outlined = type {
            layer.borderWidth = 1
        }

        if case .bleached = type {
            sora.shadow = .default
        }

        let palette = sora.style.palette

        let borderColor = palette.color((isEnabled ? type.tintColor : type.disabledBorderColor) ?? .fgPrimary).cgColor
        layer.borderColor = borderColor

        let soraBackgroundColor = isEnabled ? type.enabledBackgroundColor : type.disabledBackgroundColor
        let backgroundColor = isEnabled ? palette.color(soraBackgroundColor) : palette.color(soraBackgroundColor).withAlphaComponent(0.04)
        sora.backgroundColor = .custom(uiColor: backgroundColor)

        let soraColor = isEnabled ? type.tintColor : type.disabledTintColor
        let textColor = isEnabled ? palette.color(soraColor) : palette.color(soraColor).withAlphaComponent(0.12)
        let mainColor = isEnabled ? palette.color(soraColor) : palette.color(soraColor).withAlphaComponent(0.12)

        leftImageView.tintColor = mainColor
        titleLabel.sora.textColor = .custom(uiColor: textColor)
        rightImageView.tintColor = mainColor

        titleLabel.sora.font = size.font

        pressingView.sora.backgroundColor = .custom(uiColor: palette.color(type.pressedSublayerColor).withAlphaComponent(0.12))
    }
}

private extension SoramitsuButton {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = size.height / 2
        pressingView.layer.cornerRadius = size.height / 2
        
        addSubview(pressingView)
        addSubview(stackView)

        stackView.addArrangedSubview(leftImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(rightImageView)
        
        horizontalConstaint = stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        
        leftImageSizeConstaint = leftImageView.heightAnchor.constraint(equalToConstant: 24)
        leftImageSizeConstaint?.isActive = true
        
        rightImageSizeConstaint = rightImageView.heightAnchor.constraint(equalToConstant: 24)
        rightImageSizeConstaint?.isActive = true

        NSLayoutConstraint.activate([
            pressingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pressingView.topAnchor.constraint(equalTo: topAnchor),
            pressingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pressingView.centerYAnchor.constraint(equalTo: centerYAnchor),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightImageView.widthAnchor.constraint(equalTo: rightImageView.heightAnchor),
            leftImageView.widthAnchor.constraint(equalTo: leftImageView.heightAnchor),

            heightAnchor.constraint(equalToConstant: size.height)
        ])
    }

    func applyShadowPath() {
        layer.shadowColor = UIColor(red: 153 / 255.0, green: 153 / 255.0, blue: 153 / 255.0, alpha: 0.24).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0.0, height: 10.0)
        layer.shadowRadius = size.height / 2
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}

public extension SoramitsuButton {
    convenience init(size: SoramitsuButtonSize = .large, type: SoramitsuButtonType = .filled(.primary)) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, size: size, type: type)
    }
}
