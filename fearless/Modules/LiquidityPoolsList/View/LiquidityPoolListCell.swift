import UIKit

class LiquidityPoolListCell: UITableViewCell {
    let tokenPairIconsView = TokenPairIconsView()
    let tokenPairNameLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = .white
        return label
    }()

    let rewardTokenNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let apyLabel: UILabel = {
        let label = UILabel()
        label.font = .capsTitle
        label.textColor = R.color.colorPink()
        return label
    }()

    let stakingStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorColdGreen()
        return label
    }()

    let reservesLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        drawSubviews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        drawSubviews()
        setupConstraints()
    }

    private func drawSubviews() {
        addSubview(tokenPairIconsView)
        addSubview(tokenPairNameLabel)
        addSubview(rewardTokenNameLabel)
        addSubview(apyLabel)
        addSubview(stakingStatusLabel)
        addSubview(reservesLabel)
    }

    private func setupConstraints() {
        tokenPairIconsView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(4)
        }
        
        tokenPairNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenPairIconsView.snp.trailing).offset(8)
            make.top.equalToSuperview().inset(4)
        }
        
        rewardTokenNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenPairIconsView.snp.trailing).offset(8)
            make.bottom.equalToSuperview().inset(4)
            make.top.equalTo(tokenPairNameLabel.snp.bottom).offset(4)
        }
        
        apyLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.equalTo(tokenPairNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(tokenPairNameLabel.snp.centerY)
        }
        
        stakingStatusLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.equalTo(rewardTokenNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(rewardTokenNameLabel.snp.centerY)
        }
        
        reservesLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.equalTo(rewardTokenNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(rewardTokenNameLabel.snp.centerY)
        }
    }
}
