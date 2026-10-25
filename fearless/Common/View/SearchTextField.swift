import Foundation
import UIKit
import SoraUI

class SearchTextField: BackgroundedContentControl {
    private enum Constants {
        static let delay: CGFloat = 0.5
        static let textFieldInsets: CGFloat = 13
        static let minimumTextFieldHeight: CGFloat = 44
    }

    let textField: UITextField = {
        let textField = AccessibleSearchTextField()
        textField.borderStyle = .none
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.setContentCompressionResistancePriority(.init(999), for: .vertical)
        return textField
    }()

    var triangularedView: TriangularedView? {
        backgroundView as? TriangularedView
    }

    var onTextDidChanged: ((String?) -> Void)?

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        createUI()
        setSearchIcon()
        textField.addTarget(self, action: #selector(handleThorttle), for: UIControl.Event.editingChanged)
        textField.delegate = self
        textField.clearButtonMode = .whileEditing
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private

    private func setSearchIcon() {
        let icon = UIImageView(image: R.image.iconSearch())
        icon.isAccessibilityElement = false
        textField.leftView = icon
        textField.leftViewMode = .always
    }

    private func createUI() {
        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView?.isUserInteractionEnabled = false
        }

        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(1)
            make.leading.trailing.equalToSuperview().inset(Constants.textFieldInsets)
            make.height.greaterThanOrEqualTo(Constants.minimumTextFieldHeight).priority(999)
        }
    }

    // MARK: - Actions

    @objc private func handleThorttle() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(textFieldDidChange),
            object: nil
        )
        perform(#selector(textFieldDidChange), with: nil, afterDelay: Constants.delay)
    }

    @objc func textFieldDidChange() {
        onTextDidChanged?(textField.text)
    }
}

private final class AccessibleSearchTextField: UITextField {
    override var placeholder: String? {
        didSet {
            attributedPlaceholder = placeholder.map {
                NSAttributedString(string: $0, attributes: [.foregroundColor: R.color.colorWhite75() ?? UIColor.lightGray])
            }
        }
    }

    override var accessibilityLabel: String? {
        get {
            let label = super.accessibilityLabel
            return label?.isEmpty == false ? label : placeholder
        }
        set { super.accessibilityLabel = newValue }
    }
}

// MARK: - UITextFieldDelegate

extension SearchTextField: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onTextDidChanged?(textField.text)
        textField.resignFirstResponder()
        return true
    }
}
