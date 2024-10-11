import UIKit
import SoraUI

final class ConnectedAccountsTableCell: UITableViewCell {
    enum Position {
        case top
        case middle
        case bottom
        case list
    }

    let containerView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite4()!
        containerView.highlightedFillColor = R.color.colorWhite4()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let countLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        label.numberOfLines = 2
        return label
    }()

    private let optionsButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.isUserInteractionEnabled = false
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        model: ConnectedAccountsViewModel.Accounts,
        position: Position
    ) {
        titleLabel.text = model.title
        if let count = model.count {
            countLabel.text = "\(count)"
            optionsButton.setImage(R.image.iconHorMore(), for: .normal)
        } else {
            countLabel.text = nil
            optionsButton.setImage(R.image.iconWarning(), for: .normal)
        }

        switch position {
        case .top, .middle:
            containerView.cornerCut = .none
            containerView.cornersRaduis = .none
        case .bottom:
            containerView.cornerCut = .bottomRight
            containerView.cornersRaduis = .bottomLeft
        case .list:
            containerView.cornerCut = .none
            containerView.cornersRaduis = .none
            containerView.fillColor = R.color.colorBlack19()!
            containerView.fillColor = R.color.colorBlack19()!
            containerView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(4)
            }
        }
    }

    func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(containerView)

        let hStackView = UIFactory.default.createHorizontalStackView()
        containerView.addSubview(hStackView)
        hStackView.addArrangedSubview(titleLabel)
        hStackView.addArrangedSubview(countLabel)
        hStackView.addArrangedSubview(optionsButton)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        hStackView.snp.makeConstraints { make in
            make.top.bottom.greaterThanOrEqualToSuperview().priority(.low)
            make.leading.equalToSuperview().inset(12)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        optionsButton.snp.makeConstraints { make in
            make.size.equalTo(44)
        }
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        countLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
}
