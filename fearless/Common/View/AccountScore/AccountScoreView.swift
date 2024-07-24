import UIKit
import Cosmos

class AccountScoreView: UIView {
    private var viewModel: AccountScoreViewModel?

    let starView: CosmosView = {
        let view = CosmosView()
        view.settings.totalStars = 1
        view.settings.starSize = 15
        view.settings.textMargin = 2
        view.settings.textFont = .h6Title
        view.settings.passTouchesToSuperview = false
        view.settings.fillMode = .precise
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        addSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AccountScoreViewModel?) {
        self.viewModel = viewModel
        viewModel?.setup(with: self)
    }

    func bind(score: Int, rate: AccountScoreRate) {
        isHidden = false
        starView.text = "\(score)"

        if let color = rate.color {
            starView.settings.emptyBorderColor = color
            starView.settings.filledColor = color
            starView.settings.filledBorderColor = color
            starView.settings.textColor = color
        }

        switch rate {
        case .high:
            starView.rating = 5
        case .medium:
            starView.rating = 2.5
        case .low:
            starView.rating = 0
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
