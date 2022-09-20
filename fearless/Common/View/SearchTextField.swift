import Foundation
import UIKit
import SoraUI

class SearchTextField: BackgroundedContentControl {
    private enum Constants {
        static let delay: CGFloat = 0.5
        static let textFieldInsets: CGFloat = 13
        static let searchTextFieldHeight: CGFloat = 36
    }

    let textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
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
        setSearchLeftButton()
        textField.addTarget(self, action: #selector(handleThorttle), for: UIControl.Event.editingChanged)
        textField.delegate = self
        textField.clearButtonMode = .whileEditing
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

    private func createUI() {
        if backgroundView == nil {
            backgroundView = TriangularedView()
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

    @objc private func handleThorttle() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(textFieldDidChange),
            object: nil
        )
        perform(#selector(textFieldDidChange), with: nil, afterDelay: Constants.delay)
    }

    @objc private func handleIconSearchButton() {
        textField.becomeFirstResponder()
    }

    @objc func textFieldDidChange() {
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
