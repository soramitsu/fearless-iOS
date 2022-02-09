protocol CheckPincodeModuleOutput: AnyObject {
    func didCheck()
}

protocol CheckPincodeWireframeProtocol: AnyObject {
    func finishCheck(from view: ControllerBackedProtocol?)
}
