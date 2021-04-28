import Foundation

final class YourValidatorsPresenter {
    weak var view: YourValidatorsViewProtocol?
    let wireframe: YourValidatorsWireframeProtocol
    let interactor: YourValidatorsInteractorInputProtocol

    let viewModelFactory: YourValidatorsViewModelFactoryProtocol

    private var validatorsModel: YourValidatorsModel?
    private var controller: AccountItem?
    private var electionStatus: ElectionStatus?

    init(
        interactor: YourValidatorsInteractorInputProtocol,
        wireframe: YourValidatorsWireframeProtocol,
        viewModelFactory: YourValidatorsViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        guard let model = validatorsModel else {
            return
        }

        do {
            let sections = try viewModelFactory.createViewModel(for: model)
            view?.reload(state: .validatorList(sections))
        } catch {
            Logger.shared.error("Did receive error: \(error)")
        }
    }
}

extension YourValidatorsPresenter: YourValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectValidator(viewModel _: YourValidatorsModel) {}

    func changeValidators() {}
}

extension YourValidatorsPresenter: YourValidatorsInteractorOutputProtocol {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>) {
        switch result {
        case let .success(item):
            validatorsModel = item
        case .failure:
            return
        }

        updateView()
    }

    func didReceiveController(result: Result<AccountItem?, Error>) {
        switch result {
        case let .success(item):
            controller = item
        case .failure:
            return
        }
    }

    func didReceiveElectionStatus(result: Result<ElectionStatus, Error>) {
        switch result {
        case let .success(item):
            electionStatus = item
        case .failure:
            return
        }
    }
}
