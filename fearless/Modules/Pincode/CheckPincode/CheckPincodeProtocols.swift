protocol CheckPincodeModuleOutput: AnyObject {
    func didCheck()
    func close(view: ControllerBackedProtocol?)
}

protocol CheckPincodeWireframeProtocol: AnyObject {
    func finishCheck(from view: ControllerBackedProtocol?)
}
