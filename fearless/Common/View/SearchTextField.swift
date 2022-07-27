import Foundation
import UIKit
import SoraUI

class SearchTextField: BackgroundedContentControl {
    private enum Constants {
        static let textFieldInsets: CGFloat = 13
        static let searchTextFieldHeight: CGFloat = 36
    }

    let textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        return textField
    }()

    var triangularedView: TriangularedBlurView? {
        backgroundView as? TriangularedBlurView
    }

    var onTextDidChanged: ((String?) -> Void)?

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        createUI()
        setClearRightButton()
        setSearchLeftButton()
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private

    private func setSearchLeftButton() {
        let iconSearchButton = UIButton()
        iconSearchButton.setImage(R.image.iconSearch(), for: .normal)
        iconSearchButton.addTarget(self, action: #selector(handleIconSearchButton), for: .touchUpInside)

        textField.leftView = iconSearchButton
        textField.leftViewMode = .always
    }

    private func setClearRightButton() {
        let deleteButton = UIButton()
        deleteButton.setImage(R.image.deleteGrey(), for: .normal)
        deleteButton.addTarget(self, action: #selector(handleDeleteButton), for: .touchUpInside)

        textField.rightView = deleteButton
        textField.rightViewMode = .never
    }

    private func createUI() {
        if backgroundView == nil {
            backgroundView = TriangularedBlurView()
            backgroundView?.isUserInteractionEnabled = false
        }

        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.textFieldInsets)
            make.height.equalTo(Constants.searchTextFieldHeight)
        }
    }

    // MARK: - Actions

    @objc private func handleIconSearchButton() {
        textField.becomeFirstResponder()
    }

    @objc private func handleDeleteButton() {
        textField.text = ""
        sendActions(for: .editingChanged)
        textField.becomeFirstResponder()
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text, !text.isEmpty {
            textField.rightViewMode = .always
        } else {
            textField.rightViewMode = .never
        }

        onTextDidChanged?(textField.text)
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
