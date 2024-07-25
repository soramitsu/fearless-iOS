import UIKit

class LiquidityPoolListCell: UITableViewCell {
    let tokenPairIconsView = TokenPairIconsView()
    let tokenPairNameLabel: SkeletonLabel = {
        let label = SkeletonLabel(skeletonSize: CGSize(width: 50, height: 12))
        label.font = .capsTitle
        label.textColor = .white
        return label
    }()

    let rewardTokenNameLabel: SkeletonLabel = {
        let label = SkeletonLabel(skeletonSize: CGSize(width: 50, height: 12))
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        return label
    }()

    let apyLabel: SkeletonLabel = {
        let label = SkeletonLabel(skeletonSize: CGSize(width: 60, height: 12))
        label.font = .capsTitle
        label.textColor = R.color.colorPink()
        label.textAlignment = .right
        return label
    }()

    let stakingStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorColdGreen()
        return label
    }()

    let reservesLabel: ShimmeredLabel = {
        let label = ShimmeredLabel(skeletonSize: CGSize(width: 90, height: 12))
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        label.textAlignment = .right
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.backgroundColor = .clear
        backgroundColor = .clear
        drawSubviews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        contentView.backgroundColor = .clear
        backgroundColor = .clear

        drawSubviews()
        setupConstraints()
    }

    func bind(viewModel: LiquidityPoolListCellModel) {
        tokenPairIconsView.bind(viewModel: viewModel.tokenPairIconsVieWModel)
        stakingStatusLabel.text = viewModel.stakingStatusLabelText

        tokenPairNameLabel.updateTextWithLoading(viewModel.tokenPairNameLabelText)
        rewardTokenNameLabel.updateTextWithLoading(viewModel.rewardTokenNameLabelText)
        apyLabel.updateTextWithLoading(viewModel.apyLabelText)
        reservesLabel.updateTextWithLoading(viewModel.reservesLabelText)

        stakingStatusLabel.isHidden = viewModel.stakingStatusLabelText == nil
        reservesLabel.isHidden = viewModel.stakingStatusLabelText != nil
    }

    private func drawSubviews() {
        contentView.addSubview(tokenPairIconsView)
        contentView.addSubview(tokenPairNameLabel)
        contentView.addSubview(rewardTokenNameLabel)
        contentView.addSubview(apyLabel)
        contentView.addSubview(stakingStatusLabel)
        contentView.addSubview(reservesLabel)
    }

    private func setupConstraints() {
        tokenPairIconsView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.width.equalTo(40)
            make.height.equalTo(37)
            make.centerY.equalToSuperview()
        }

        tokenPairNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenPairIconsView.snp.trailing).offset(8)
            make.top.equalToSuperview().inset(5)
            make.height.equalTo(15)
        }

        rewardTokenNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenPairIconsView.snp.trailing).offset(8)
            make.bottom.equalToSuperview().inset(5)
            make.top.equalTo(tokenPairNameLabel.snp.bottom).offset(4)
            make.height.equalTo(15)
        }

        apyLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(tokenPairNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(tokenPairNameLabel.snp.centerY)
            make.height.equalTo(15)
        }

        stakingStatusLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(rewardTokenNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(rewardTokenNameLabel.snp.centerY)
            make.height.equalTo(15)
        }

        reservesLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(rewardTokenNameLabel.snp.trailing).offset(8)
            make.centerY.equalTo(rewardTokenNameLabel.snp.centerY)
            make.height.equalTo(15)
        }
    }
}
