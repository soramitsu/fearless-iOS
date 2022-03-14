import SoraFoundation

struct AccountCreateViewModel: InputViewModelProtocol {
    let chainType: AccountCreateChainType
    let title: String
    let placeholder: String
    let inputHandler: InputHandling
    let autocapitalization: UITextAutocapitalizationType

    public init(
        chainType: AccountCreateChainType,
        inputHandler: InputHandling,
        title: String = "",
        placeholder: String = "",
        autocapitalization: UITextAutocapitalizationType = .sentences
    ) {
        self.chainType = chainType
        self.title = title
        self.placeholder = placeholder
        self.inputHandler = inputHandler
        self.autocapitalization = autocapitalization
    }
}
