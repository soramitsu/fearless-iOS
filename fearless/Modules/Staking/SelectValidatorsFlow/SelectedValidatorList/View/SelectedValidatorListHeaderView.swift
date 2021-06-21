import UIKit

class SelectedValidatorListHeaderView: CustomValidatorListHeaderView {
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TitleWithSubtitleViewModel, shouldAlert: Bool) {
        bind(title: viewModel.title, details: viewModel.subtitle)

        let color: UIColor = shouldAlert ?
            R.color.colorRed()! :
            R.color.colorLightGray()!

        titleLabel.textColor = color
    }
}
