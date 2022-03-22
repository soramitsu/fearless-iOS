import UIKit

final class CrowdloanWikiTableViewCell: UITableViewCell {
    let wikiCrowdloansView = UIFactory.default.createLearnMoreView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: LearnMoreViewModel) {
        wikiCrowdloansView.bind(viewModel: viewModel)
    }

    private func setupLayout() {
        contentView.addSubview(wikiCrowdloansView)
        wikiCrowdloansView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
