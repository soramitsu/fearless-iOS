import UIKit

final class TitleCopyableValueView: TitleValueView {
    var onCopy: (() -> Void)?

    let copyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconCopy(), for: .normal)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCopyButton()
        valueImageView.isHidden = true
        valueStackView.setCustomSpacing(0, after: valueLabel)
    }

    private func setupCopyButton() {
        valueStackView.addArrangedSubview(copyButton)

        copyButton.addAction { [weak self] in
            UIPasteboard.general.string = self?.valueLabel.text
            self?.onCopy?()
        }

        copyButton.snp.makeConstraints { make in
            make.size.equalTo(30)
        }
    }
}
