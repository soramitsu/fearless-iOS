import UIKit
import RobinHood

final class SignerConfirmInteractor {
    weak var presenter: SignerConfirmInteractorOutputProtocol!

    let request: SignerOperationRequestProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol

    init(
        request: SignerOperationRequestProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol
    ) {

    }
}

extension SignerConfirmInteractor: SignerConfirmInteractorInputProtocol {}
