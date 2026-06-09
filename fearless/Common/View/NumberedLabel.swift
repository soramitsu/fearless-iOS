import Foundation
import UIKit

final class NumberedLabel: UIView {
    let numberLabel = UILabel()
    let textLabel = UILabel()

    init(with number: Int) {
        super.init(frame: .zero)
        numberLabel.text = "\(number)."
        textLabel.numberOfLines = 0
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        numberLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        addSubview(numberLabel)
        numberLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
        }

        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(numberLabel.snp.trailing).offset(UIConstants.bigOffset)
            make.top.trailing.bottom.equalToSuperview()
        }
    }
}
