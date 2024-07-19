import UIKit
import Cosmos

class AccountScoreView: UIView {
    let starView: CosmosView = {
        let view = CosmosView()
        view.settings.totalStars = 1
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AccountScoreViewModel) {
        starView.text = viewModel.accountScoreLabelText

        starView.settings.textFont = .h5Title
        if let color = viewModel.rate.color {
            starView.settings.emptyBorderColor = color
            starView.settings.filledColor = color
            starView.settings.filledBorderColor = color
            starView.settings.textColor = color
        }

        switch viewModel.rate {
        case .high:
            starView.settings.fillMode = .full
        case .medium:
            starView.settings.fillMode = .half
        case .low:
            starView.settings.fillMode = .precise
        }
    }

    private func addSubviews() {
        addSubview(starView)
    }

    private func setupConstraints() {
        starView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(15)
        }
    }
}
