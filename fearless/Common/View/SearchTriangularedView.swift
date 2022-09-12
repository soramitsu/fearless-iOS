import UIKit
import SoraUI
import FearlessUtils

final class SearchTriangularedView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 32
        static let viewHeight: CGFloat = 64
        static let verticalOffset: CGFloat = 12
        static let buttonSize: CGFloat = 16
    }

    private let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorDarkGray()!
        view.highlightedStrokeColor = R.color.colorDarkGray()!
        view.strokeWidth = 1.0
        return view
    }()

    private let addressImage: PolkadotIconView = {
        let view = PolkadotIconView()
        view.isHidden = true
        return view
    }()

    private let placeholderImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.addressPlaceholder()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let cleanButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.deleteGrey()?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = .white
        button.isHidden = true
        button.addTarget(self, action: #selector(clean), for: .touchUpInside)
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = .white
        return label
    }()

    let textField: UITextField = {
        let view = UITextField()
        view.tintColor = R.color.colorPinkTint()
        view.font = .p1Paragraph
        view.textColor = .white
        view.returnKeyType = .done
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateState(icon: DrawableIcon?) {
        if let text = textField.text, text.isNotEmpty {
            cleanButton.isHidden = false
        } else {
            cleanButton.isHidden = true
        }
        if let icon = icon {
            addressImage.bind(icon: icon)
            addressImage.isHidden = false
            placeholderImage.isHidden = true
        } else {
            addressImage.isHidden = true
            placeholderImage.isHidden = false
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(LayoutConstants.viewHeight)
        }

        addSubview(addressImage)
        addressImage.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }
        addSubview(placeholderImage)
        placeholderImage.snp.makeConstraints { make in
            make.edges.equalTo(addressImage)
        }

        addSubview(cleanButton)
        cleanButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.buttonSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(addressImage.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalTo(cleanButton.snp.leading).offset(-UIConstants.defaultOffset)
            make.top.equalToSuperview().inset(LayoutConstants.verticalOffset)
        }

        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(LayoutConstants.verticalOffset)
        }
    }

    @objc
    private func clean() {
        textField.text = nil
        _ = textField.delegate?.textFieldShouldClear?(textField)
        updateState(icon: nil)
    }
}
