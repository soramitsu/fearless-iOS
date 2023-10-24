import Foundation
import UIKit

final class WalletDetailsTableHeaderView: UITableViewHeaderFooterView {
    private let label: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorAlmostWhite()!
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(text: String) {
        label.text = text.uppercased()
    }

    private func setupLayout() {
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
        }
    }
}
