import Foundation
import UIKit
import SoraUI

class SearchTextField: BackgroundedContentControl {
    private enum Constants {
        static let delay: CGFloat = 0.5
        static let textFieldInsets: CGFloat = 13
        static let textFieldVerticalInset: CGFloat = 1
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
        // A stack view gives its spare height to the view that hugs least; that must be the list, never the field.
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // BackgroundedContentControl sizes itself from `contentView`, which this control leaves empty, so it reported a
    // zero height and selection sheets stretched the field over most of the screen (iOS 4.2.0 2026.11.5). The width
    // stays as it was.
    override var intrinsicContentSize: CGSize {
        let fieldHeight = max(Constants.minimumTextFieldHeight, textField.intrinsicContentSize.height)
        return CGSize(
            width: super.intrinsicContentSize.width,
            height: fieldHeight + 2 * Constants.textFieldVerticalInset
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            invalidateIntrinsicContentSize()
        }
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
            make.top.bottom.equalToSuperview().inset(Constants.textFieldVerticalInset)
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
