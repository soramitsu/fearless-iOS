import UIKit

final class SelectedValidatorListHeaderView: CustomValidatorListHeaderView {
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TitleWithSubtitleViewModel, shouldAlert: Bool) {
        bind(viewModel: viewModel)

        let color: UIColor = shouldAlert ?
            R.color.colorRed()! :
            R.color.colorLightGray()!

        titleLabel.textColor = color
    }
}
