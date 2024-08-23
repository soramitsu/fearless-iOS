import SoraFoundation

struct AccountCreateViewModel: InputViewModelProtocol {
    let title: String
    let placeholder: String
    let inputHandler: InputHandling
    let autocapitalization: UITextAutocapitalizationType

    init(
        inputHandler: InputHandling,
        title: String = "",
        placeholder: String = "",
        autocapitalization: UITextAutocapitalizationType = .sentences
    ) {
        self.title = title
        self.placeholder = placeholder
        self.inputHandler = inputHandler
        self.autocapitalization = autocapitalization
    }
}
