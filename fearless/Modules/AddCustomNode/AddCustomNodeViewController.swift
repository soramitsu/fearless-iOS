import UIKit
import SoraUI
import SoraFoundation

final class AddCustomNodeViewController: UIViewController, ViewHolder {
    typealias RootViewType = AddCustomNodeViewLayout

    let presenter: AddCustomNodePresenterProtocol
    
    private var nameInputViewModel: InputViewModelProtocol?
    private var urlAddressInputViewModel: InputViewModelProtocol?


    init(presenter: AddCustomNodePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AddCustomNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        
        rootView.nodeNameInputView.animatedInputField.delegate = self
        rootView.nodeAddressInputView.animatedInputField.delegate = self
    }
}

extension AddCustomNodeViewController: AddCustomNodeViewProtocol {}

extension AddCustomNodeViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if let textField = rootView.nodeNameInputView.animatedInputField.textField {
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange,
                                                           with: string)
                presenter.nameTextFieldValueChanged(updatedText)
            }
        }
        
        if let textField = rootView.nodeAddressInputView.animatedInputField.textField {
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange,
                                                           with: string)
                presenter.addressTextFieldValueChanged(updatedText)
            }
        }
        
        return true
       
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}
