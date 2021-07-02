protocol SignerConnectViewProtocol: AnyObject {}

protocol SignerConnectPresenterProtocol: AnyObject {
    func setup()
}

protocol SignerConnectInteractorInputProtocol: AnyObject {
    func connect()
}

protocol SignerConnectInteractorOutputProtocol: AnyObject {}

protocol SignerConnectWireframeProtocol: AnyObject {}
