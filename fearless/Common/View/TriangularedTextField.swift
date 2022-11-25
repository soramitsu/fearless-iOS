import SoraUI
import UIKit

final class TriangularedTextField: TriangularedView {
    enum LayoutConstants {
        static let height: CGFloat = 64
        static let spacing: CGFloat = 12
    }

    let textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.textColor = R.color.colorWhite()
        textField.font = .h4Title
        textField.returnKeyType = .done
        textField.tintColor = R.color.colorWhite()
        return textField
    }()

    // MARK: - Constructor

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()

        fillColor = R.color.colorSemiBlack()!
        highlightedFillColor = R.color.colorSemiBlack()!
        strokeColor = R.color.colorWhite8()!
        highlightedStrokeColor = R.color.colorWhite8()!
        shadowOpacity = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    func setupLayout() {
        snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.height)
        }

        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(LayoutConstants.spacing)
            make.trailing.equalToSuperview().offset(-LayoutConstants.spacing)
        }
    }
}
