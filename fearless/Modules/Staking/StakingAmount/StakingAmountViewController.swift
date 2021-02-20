import UIKit
import SoraFoundation
import SoraUI

final class StakingAmountViewController: UIViewController, AdaptiveDesignable {
    var presenter: StakingAmountPresenterProtocol!

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var amountInputView: AmountInputView!
    @IBOutlet private var restakeView: RewardSelectionView!
    @IBOutlet private var payoutView: RewardSelectionView!
    @IBOutlet private var chooseRewardView: UIView!

    private var accountContainerView: UIView?
    private var accountView: DetailsTriangularedView?

    var uiFactory: UIFactoryProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                                style: .plain,
                                                target: self,
                                                action: #selector(actionClose))

        navigationItem.leftBarButtonItem = closeBarItem
    }

    @objc private func actionClose() {
        presenter.close()
    }

    // MARK: Private

    private func createAccountViewIfNeeded() {
        guard accountContainerView == nil else {
            return
        }

        let accountView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: false)
        accountView.translatesAutoresizingMaskIntoConstraints = false
        self.accountView = accountView

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.addSubview(accountView)
        self.accountContainerView = containerView

        accountView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                             constant: UIConstants.horizontalInset).isActive = true

        accountView.rightAnchor.constraint(equalTo: containerView.rightAnchor,
                                           constant: -UIConstants.horizontalInset).isActive = true

        accountView.heightAnchor.constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true

        accountView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12.0).isActive = true
        accountView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0.0).isActive = true
    }

    private func updateAccountView() {
        if restakeView.isSelected, let containerView = accountContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()

            accountContainerView = nil
            accountView = nil
        }

        if payoutView.isSelected {
            createAccountViewIfNeeded()

            if let containerView = accountContainerView,
               let insertionIndex = stackView.arrangedSubviews
                .firstIndex(where: { $0 == chooseRewardView }) {
                stackView.insertArrangedSubview(containerView, at: insertionIndex + 1)
            }
        }
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)
        amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupLocalization() {
        setupBalanceAccessoryView()
    }

    // MARK: Action

    @IBAction private func actionRestake() {
        restakeView.isSelected = true
        payoutView.isSelected = false

        updateAccountView()
    }

    @IBAction private func actionPayout() {
        restakeView.isSelected = false
        payoutView.isSelected = true

        updateAccountView()
    }
}

extension StakingAmountViewController: StakingAmountViewProtocol {}

extension StakingAmountViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on view: AmountInputAccessoryView, percentage: CGFloat) {

    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingAmountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
