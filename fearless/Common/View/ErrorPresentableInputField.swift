import UIKit

final class ErrorPresentableInputField: UIView {
    enum State {
        case normal
        case error(text: String)

        var errorViewVisible: Bool {
            switch self {
            case .normal:
                return false
            case .error:
                return true
            }
        }

        var errorText: String? {
            switch self {
            case .normal:
                return nil
            case let .error(text):
                return text
            }
        }
    }

    let state: State = .normal
    let inputField: UIView

    let errorImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconError()
        return imageView
    }()

    let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorRed()
        label.font = .p3Paragraph
        label.numberOfLines = 0
        return label
    }()

    let errorContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    init(inputField: UIView) {
        self.inputField = inputField

        super.init(frame: .zero)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(state: ErrorPresentableInputField.State) {
        errorLabel.text = state.errorText
        errorContainer.isHidden = !state.errorViewVisible
        applyConstraints(for: state)
    }

    // MARK: Private

    private func setupLayout() {
        addSubview(inputField)
        addSubview(errorContainer)

        errorContainer.addSubview(errorImageView)
        errorContainer.addSubview(errorLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        errorImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        errorLabel.snp.makeConstraints { make in
            make.leading.equalTo(errorImageView.snp.trailing).offset(UIConstants.defaultOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.trailing.equalToSuperview()
        }

        inputField.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        errorContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(inputField.snp.bottom).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }

    private func applyConstraints(for state: ErrorPresentableInputField.State) {
        switch state {
        case .normal:
            inputField.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.leading.trailing.equalToSuperview()
                make.bottom.equalToSuperview()
            }

            errorContainer.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            }
        case .error:
            inputField.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.leading.trailing.equalToSuperview()
            }

            errorContainer.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
                make.top.equalTo(inputField.snp.bottom).offset(UIConstants.defaultOffset)
                make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            }
        }
    }
}
