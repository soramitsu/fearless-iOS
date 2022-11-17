typealias ScanQRModuleCreationResult = (view: ScanQRViewInput, input: ScanQRModuleInput)

protocol ScanQRViewInput: ControllerBackedProtocol {}

protocol ScanQRViewOutput: AnyObject {
    func didLoad(view: ScanQRViewInput)
}

protocol ScanQRInteractorInput: AnyObject {
    func setup(with output: ScanQRInteractorOutput)
}

protocol ScanQRInteractorOutput: AnyObject {}

protocol ScanQRRouterInput: AnyObject {}

protocol ScanQRModuleInput: AnyObject {}

protocol ScanQRModuleOutput: AnyObject {}
