import UIKit
import SoraUI
import SnapKit

final class ChooseRecipientViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChooseRecipientViewLayout

    let presenter: ChooseRecipientPresenterProtocol

    private var tableViewModel: ChooseRecipientTableViewModel?

    private lazy var searchActivityIndicatory: UIActivityIndicatorView = .init(style: .white)

    init(presenter: ChooseRecipientPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChooseRecipientViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        configure()

        navigationController?.setNavigationBarHidden(true, animated: false)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func configure() {
        rootView.searchView.textField.delegate = self

        rootView.tableView.registerClassForCell(SearchPeopleTableCell.self)
        rootView.tableView.tableFooterView = UIView()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.nextButton.addTarget(self, action: #selector(nextButtonClicked), for: .touchUpInside)
        rootView.scanButton.addTarget(self, action: #selector(scanButtonClicked), for: .touchUpInside)
        rootView.historyButton.addTarget(self, action: #selector(historyButtonClicked), for: .touchUpInside)
        rootView.pasteButton.addTarget(self, action: #selector(pasteButtonClicked), for: .touchUpInside)
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func scanButtonClicked() {
        presenter.didTapScanButton()
    }

    @objc private func pasteButtonClicked() {
        presenter.didTapPasteButton()
    }

    @objc private func historyButtonClicked() {
        presenter.didTapHistoryButton()
    }

    @objc private func nextButtonClicked() {
        guard let address = rootView.searchView.textField.text else {
            return
        }
        presenter.didTapNextButton(with: address)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            rootView.keyboardAdoptableConstraint?.update(inset: keyboardSize.height + 16)
        }
    }

    @objc private func keyboardWillHide(notification _: NSNotification) {
        rootView.keyboardAdoptableConstraint?.update(inset: 16)
    }
}

extension ChooseRecipientViewController: ChooseRecipientViewProtocol {
    func didReceive(scamInfo: ScamInfo?, assetName: String) {
        rootView.bind(scamInfo: scamInfo, assetName: assetName)
    }

    func didReceive(viewModel: ChooseRecipientViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(tableViewModel: ChooseRecipientTableViewModel) {
        self.tableViewModel = tableViewModel
        rootView.tableView.isHidden = tableViewModel.results.isEmpty
        rootView.tableView.reloadData()
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
    }

    func didReceive(address: String) {
        rootView.searchView.textField.text = address
    }
}

extension ChooseRecipientViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        tableViewModel?.results.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = tableViewModel,
              let cell = tableView.dequeueReusableCellWithType(SearchPeopleTableCell.self) else {
            return UITableViewCell()
        }
        cell.bind(to: viewModel.results[indexPath.row])
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = tableViewModel else {
            return
        }
        rootView.searchView.textField.text = viewModel.results[indexPath.row].address
        presenter.didSelectViewModel(cellViewModel: viewModel.results[indexPath.row])
    }
}

extension ChooseRecipientViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)

        presenter.searchTextDidChanged(newString)
        return true
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        presenter.searchTextDidChanged("")
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else {
            return false
        }

        presenter.searchTextDidChanged(text)
        return false
    }
}

extension ChooseRecipientViewController: HiddableBarWhenPushed {}

// extension ChooseRecipientViewController: KeyboardViewAdoptable {
//    var target: Constraint? { rootView.keyboardAdoptableConstraint }
//
//    var shouldApplyKeyboardFrame: Bool { isFirstLayoutCompleted }
//
//    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat {
//        UIConstants.bigOffset
//    }
//
//    func updateWhileKeyboardFrameChanging(_: CGRect) {}
// }
