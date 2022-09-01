import UIKit
import SoraUI
import FearlessUtils

final class SearchTriangularedView: UIView {
    enum LayoutConstants {
        static let iconSize: CGFloat = 32
        static let viewHeight: CGFloat = 52
    }

    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorDarkGray()!
        view.highlightedStrokeColor = R.color.colorDarkGray()!
        view.strokeWidth = 1.0
        return view
    }()

    let addressImage: PolkadotIconView = {
        let view = PolkadotIconView()
        view.isHidden = true
        return view
    }()

    let placeholderImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.addressPlaceholder()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let cleanButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.isHidden = true
        button.addTarget(self, action: #selector(cleanTextField), for: .touchUpInside)
        return button
    }()

    let animatedInputField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.placeholderFont = .p1Paragraph
        field.placeholderColor = R.color.colorGray()!
        field.textColor = R.color.colorWhite()!
        field.textFont = .p1Paragraph
        field.cursorColor = R.color.colorWhite()!
        return field
    }()

    var text: String? {
        get {
            animatedInputField.text
        }
        set {
            animatedInputField.text = newValue
        }
    }

    var title: String? {
        get {
            animatedInputField.title
        }
        set {
            animatedInputField.title = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            make.size.equalTo(LayoutConstants.iconSize)
        }

        addSubview(animatedInputField)
        animatedInputField.snp.makeConstraints { make in
            make.leading.equalTo(addressImage.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalTo(cleanButton.snp.leading).inset(UIConstants.defaultOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }
    }

    @objc
    private func cleanTextField() {
        animatedInputField.text = ""
    }
}
