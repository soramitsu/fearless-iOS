import Cuckoo
@testable import fearless

import UIKit


 class MockAlertPresentable: AlertPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = AlertPresentable
    
     typealias Stubbing = __StubbingProxy_AlertPresentable
     typealias Verification = __VerificationProxy_AlertPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AlertPresentable?

     func enableDefaultImplementation(_ stub: AlertPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AlertPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAlertPresentable.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AlertPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AlertPresentableStub: AlertPresentable {
    

    

    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import UIKit


 class MockControllerBackedProtocol: ControllerBackedProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ControllerBackedProtocol
    
     typealias Stubbing = __StubbingProxy_ControllerBackedProtocol
     typealias Verification = __VerificationProxy_ControllerBackedProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ControllerBackedProtocol?

     func enableDefaultImplementation(_ stub: ControllerBackedProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ControllerBackedProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockControllerBackedProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	}

	 struct __VerificationProxy_ControllerBackedProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ControllerBackedProtocolStub: ControllerBackedProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import fearless

import SoraUI
import UIKit


 class MockLoadableViewProtocol: LoadableViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = LoadableViewProtocol
    
     typealias Stubbing = __StubbingProxy_LoadableViewProtocol
     typealias Verification = __VerificationProxy_LoadableViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: LoadableViewProtocol?

     func enableDefaultImplementation(_ stub: LoadableViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var loadableContentView: UIView! {
        get {
            return cuckoo_manager.getter("loadableContentView",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.loadableContentView)
        }
        
    }
    
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return cuckoo_manager.getter("shouldDisableInteractionWhenLoading",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.shouldDisableInteractionWhenLoading)
        }
        
    }
    

    

    
    
    
     func didStartLoading()  {
        
    return cuckoo_manager.call("didStartLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStartLoading())
        
    }
    
    
    
     func didStopLoading()  {
        
    return cuckoo_manager.call("didStopLoading()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didStopLoading())
        
    }
    

	 struct __StubbingProxy_LoadableViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var loadableContentView: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView")
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockLoadableViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading")
	    }
	    
	    
	    func didStartLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStartLoading()", parameterMatchers: matchers))
	    }
	    
	    func didStopLoading() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockLoadableViewProtocol.self, method: "didStopLoading()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_LoadableViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var loadableContentView: Cuckoo.VerifyReadOnlyProperty<UIView?> {
	        return .init(manager: cuckoo_manager, name: "loadableContentView", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var shouldDisableInteractionWhenLoading: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "shouldDisableInteractionWhenLoading", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func didStartLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStartLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didStopLoading() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didStopLoading()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class LoadableViewProtocolStub: LoadableViewProtocol {
    
    
     var loadableContentView: UIView! {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIView?).self)
        }
        
    }
    
    
     var shouldDisableInteractionWhenLoading: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
     func didStartLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didStopLoading()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation
import SafariServices
import UIKit


 class MockWebPresentable: WebPresentable, Cuckoo.ProtocolMock {
    
     typealias MocksType = WebPresentable
    
     typealias Stubbing = __StubbingProxy_WebPresentable
     typealias Verification = __VerificationProxy_WebPresentable

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: WebPresentable?

     func enableDefaultImplementation(_ stub: WebPresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    

	 struct __StubbingProxy_WebPresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockWebPresentable.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_WebPresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class WebPresentableStub: WebPresentable {
    

    

    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import IrohaCrypto
import SoraFoundation


 class MockAccountCreateViewProtocol: AccountCreateViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateViewProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateViewProtocol
     typealias Verification = __VerificationProxy_AccountCreateViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateViewProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(mnemonic: [String])  {
        
    return cuckoo_manager.call("set(mnemonic: [String])",
            parameters: (mnemonic),
            escapingParameters: (mnemonic),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(mnemonic: mnemonic))
        
    }
    
    
    
     func setSelectedCrypto(model: TitleWithSubtitleViewModel)  {
        
    return cuckoo_manager.call("setSelectedCrypto(model: TitleWithSubtitleViewModel)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedCrypto(model: model))
        
    }
    
    
    
     func setSelectedNetwork(model: IconWithTitleViewModel)  {
        
    return cuckoo_manager.call("setSelectedNetwork(model: IconWithTitleViewModel)",
            parameters: (model),
            escapingParameters: (model),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setSelectedNetwork(model: model))
        
    }
    
    
    
     func setDerivationPath(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("setDerivationPath(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setDerivationPath(viewModel: viewModel))
        
    }
    
    
    
     func didCompleteCryptoTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteCryptoTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteCryptoTypeSelection())
        
    }
    
    
    
     func didCompleteNetworkTypeSelection()  {
        
    return cuckoo_manager.call("didCompleteNetworkTypeSelection()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteNetworkTypeSelection())
        
    }
    
    
    
     func didValidateDerivationPath(_ status: FieldStatus)  {
        
    return cuckoo_manager.call("didValidateDerivationPath(_: FieldStatus)",
            parameters: (status),
            escapingParameters: (status),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didValidateDerivationPath(status))
        
    }
    

	 struct __StubbingProxy_AccountCreateViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockAccountCreateViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([String])> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "set(mnemonic: [String])", parameterMatchers: matchers))
	    }
	    
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TitleWithSubtitleViewModel)> where M1.MatchedType == TitleWithSubtitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(TitleWithSubtitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setSelectedCrypto(model: TitleWithSubtitleViewModel)", parameterMatchers: matchers))
	    }
	    
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(IconWithTitleViewModel)> where M1.MatchedType == IconWithTitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(IconWithTitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setSelectedNetwork(model: IconWithTitleViewModel)", parameterMatchers: matchers))
	    }
	    
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "setDerivationPath(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteCryptoTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didCompleteCryptoTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didCompleteNetworkTypeSelection() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didCompleteNetworkTypeSelection()", parameterMatchers: matchers))
	    }
	    
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(FieldStatus)> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateViewProtocol.self, method: "didValidateDerivationPath(_: FieldStatus)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(mnemonic: M1) -> Cuckoo.__DoNotUse<([String]), Void> where M1.MatchedType == [String] {
	        let matchers: [Cuckoo.ParameterMatcher<([String])>] = [wrap(matchable: mnemonic) { $0 }]
	        return cuckoo_manager.verify("set(mnemonic: [String])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedCrypto<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(TitleWithSubtitleViewModel), Void> where M1.MatchedType == TitleWithSubtitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(TitleWithSubtitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedCrypto(model: TitleWithSubtitleViewModel)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setSelectedNetwork<M1: Cuckoo.Matchable>(model: M1) -> Cuckoo.__DoNotUse<(IconWithTitleViewModel), Void> where M1.MatchedType == IconWithTitleViewModel {
	        let matchers: [Cuckoo.ParameterMatcher<(IconWithTitleViewModel)>] = [wrap(matchable: model) { $0 }]
	        return cuckoo_manager.verify("setSelectedNetwork(model: IconWithTitleViewModel)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func setDerivationPath<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("setDerivationPath(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteCryptoTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteCryptoTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteNetworkTypeSelection() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteNetworkTypeSelection()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didValidateDerivationPath<M1: Cuckoo.Matchable>(_ status: M1) -> Cuckoo.__DoNotUse<(FieldStatus), Void> where M1.MatchedType == FieldStatus {
	        let matchers: [Cuckoo.ParameterMatcher<(FieldStatus)>] = [wrap(matchable: status) { $0 }]
	        return cuckoo_manager.verify("didValidateDerivationPath(_: FieldStatus)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateViewProtocolStub: AccountCreateViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(mnemonic: [String])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedCrypto(model: TitleWithSubtitleViewModel)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setSelectedNetwork(model: IconWithTitleViewModel)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func setDerivationPath(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteCryptoTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteNetworkTypeSelection()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didValidateDerivationPath(_ status: FieldStatus)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreatePresenterProtocol: AccountCreatePresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreatePresenterProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreatePresenterProtocol
     typealias Verification = __VerificationProxy_AccountCreatePresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreatePresenterProtocol?

     func enableDefaultImplementation(_ stub: AccountCreatePresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func selectCryptoType()  {
        
    return cuckoo_manager.call("selectCryptoType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectCryptoType())
        
    }
    
    
    
     func selectNetworkType()  {
        
    return cuckoo_manager.call("selectNetworkType()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.selectNetworkType())
        
    }
    
    
    
     func activateInfo()  {
        
    return cuckoo_manager.call("activateInfo()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateInfo())
        
    }
    
    
    
     func validate()  {
        
    return cuckoo_manager.call("validate()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.validate())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_AccountCreatePresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func selectCryptoType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "selectCryptoType()", parameterMatchers: matchers))
	    }
	    
	    func selectNetworkType() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "selectNetworkType()", parameterMatchers: matchers))
	    }
	    
	    func activateInfo() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "activateInfo()", parameterMatchers: matchers))
	    }
	    
	    func validate() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "validate()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreatePresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreatePresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectCryptoType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectCryptoType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func selectNetworkType() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("selectNetworkType()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateInfo() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateInfo()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func validate() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("validate()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreatePresenterProtocolStub: AccountCreatePresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectCryptoType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func selectNetworkType()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateInfo()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func validate()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorInputProtocol: AccountCreateInteractorInputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorInputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorInputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorInputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorInputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorInputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func createAccount(request: AccountCreationRequest)  {
        
    return cuckoo_manager.call("createAccount(request: AccountCreationRequest)",
            parameters: (request),
            escapingParameters: (request),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createAccount(request: request))
        
    }
    

	 struct __StubbingProxy_AccountCreateInteractorInputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorInputProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func createAccount<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreationRequest)> where M1.MatchedType == AccountCreationRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationRequest)>] = [wrap(matchable: request) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorInputProtocol.self, method: "createAccount(request: AccountCreationRequest)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorInputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createAccount<M1: Cuckoo.Matchable>(request: M1) -> Cuckoo.__DoNotUse<(AccountCreationRequest), Void> where M1.MatchedType == AccountCreationRequest {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationRequest)>] = [wrap(matchable: request) { $0 }]
	        return cuckoo_manager.verify("createAccount(request: AccountCreationRequest)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateInteractorInputProtocolStub: AccountCreateInteractorInputProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func createAccount(request: AccountCreationRequest)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateInteractorOutputProtocol: AccountCreateInteractorOutputProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateInteractorOutputProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateInteractorOutputProtocol
     typealias Verification = __VerificationProxy_AccountCreateInteractorOutputProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateInteractorOutputProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateInteractorOutputProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(metadata: AccountCreationMetadata)  {
        
    return cuckoo_manager.call("didReceive(metadata: AccountCreationMetadata)",
            parameters: (metadata),
            escapingParameters: (metadata),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(metadata: metadata))
        
    }
    
    
    
     func didReceiveMnemonicGeneration(error: Error)  {
        
    return cuckoo_manager.call("didReceiveMnemonicGeneration(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveMnemonicGeneration(error: error))
        
    }
    
    
    
     func didCompleteAccountCreation()  {
        
    return cuckoo_manager.call("didCompleteAccountCreation()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didCompleteAccountCreation())
        
    }
    
    
    
     func didReceiveAccountCreation(error: Error)  {
        
    return cuckoo_manager.call("didReceiveAccountCreation(error: Error)",
            parameters: (error),
            escapingParameters: (error),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceiveAccountCreation(error: error))
        
    }
    

	 struct __StubbingProxy_AccountCreateInteractorOutputProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreationMetadata)> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceive(metadata: AccountCreationMetadata)", parameterMatchers: matchers))
	    }
	    
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceiveMnemonicGeneration(error: Error)", parameterMatchers: matchers))
	    }
	    
	    func didCompleteAccountCreation() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didCompleteAccountCreation()", parameterMatchers: matchers))
	    }
	    
	    func didReceiveAccountCreation<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(Error)> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateInteractorOutputProtocol.self, method: "didReceiveAccountCreation(error: Error)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateInteractorOutputProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable>(metadata: M1) -> Cuckoo.__DoNotUse<(AccountCreationMetadata), Void> where M1.MatchedType == AccountCreationMetadata {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreationMetadata)>] = [wrap(matchable: metadata) { $0 }]
	        return cuckoo_manager.verify("didReceive(metadata: AccountCreationMetadata)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveMnemonicGeneration<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveMnemonicGeneration(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didCompleteAccountCreation() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("didCompleteAccountCreation()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didReceiveAccountCreation<M1: Cuckoo.Matchable>(error: M1) -> Cuckoo.__DoNotUse<(Error), Void> where M1.MatchedType == Error {
	        let matchers: [Cuckoo.ParameterMatcher<(Error)>] = [wrap(matchable: error) { $0 }]
	        return cuckoo_manager.verify("didReceiveAccountCreation(error: Error)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateInteractorOutputProtocolStub: AccountCreateInteractorOutputProtocol {
    

    

    
     func didReceive(metadata: AccountCreationMetadata)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveMnemonicGeneration(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didCompleteAccountCreation()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func didReceiveAccountCreation(error: Error)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockAccountCreateWireframeProtocol: AccountCreateWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountCreateWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_AccountCreateWireframeProtocol
     typealias Verification = __VerificationProxy_AccountCreateWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountCreateWireframeProtocol?

     func enableDefaultImplementation(_ stub: AccountCreateWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: AccountCreateViewProtocol?)  {
        
    return cuckoo_manager.call("proceed(from: AccountCreateViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view))
        
    }
    
    
    
     func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentCryptoTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [SNAddressType], selectedType: SNAddressType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)  {
        
    return cuckoo_manager.call("presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [SNAddressType], selectedType: SNAddressType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)",
            parameters: (view, availableTypes, selectedType, delegate, context),
            escapingParameters: (view, availableTypes, selectedType, delegate, context),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.presentNetworkTypeSelection(from: view, availableTypes: availableTypes, selectedType: selectedType, delegate: delegate, context: context))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_AccountCreateWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?)> where M1.OptionalMatchedType == AccountCreateViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "proceed(from: AccountCreateViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.ProtocolStubNoReturnFunction<(AccountCreateViewProtocol?, [SNAddressType], SNAddressType, ModalPickerViewControllerDelegate?, AnyObject?)> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [SNAddressType], M3.MatchedType == SNAddressType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [SNAddressType], SNAddressType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [SNAddressType], selectedType: SNAddressType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountCreateWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountCreateWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("proceed(from: AccountCreateViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentCryptoTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [CryptoType], M3.MatchedType == CryptoType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [CryptoType], CryptoType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentCryptoTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func presentNetworkTypeSelection<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, M5: Cuckoo.OptionalMatchable>(from view: M1, availableTypes: M2, selectedType: M3, delegate: M4, context: M5) -> Cuckoo.__DoNotUse<(AccountCreateViewProtocol?, [SNAddressType], SNAddressType, ModalPickerViewControllerDelegate?, AnyObject?), Void> where M1.OptionalMatchedType == AccountCreateViewProtocol, M2.MatchedType == [SNAddressType], M3.MatchedType == SNAddressType, M4.OptionalMatchedType == ModalPickerViewControllerDelegate, M5.OptionalMatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountCreateViewProtocol?, [SNAddressType], SNAddressType, ModalPickerViewControllerDelegate?, AnyObject?)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: availableTypes) { $0.1 }, wrap(matchable: selectedType) { $0.2 }, wrap(matchable: delegate) { $0.3 }, wrap(matchable: context) { $0.4 }]
	        return cuckoo_manager.verify("presentNetworkTypeSelection(from: AccountCreateViewProtocol?, availableTypes: [SNAddressType], selectedType: SNAddressType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountCreateWireframeProtocolStub: AccountCreateWireframeProtocol {
    

    

    
     func proceed(from view: AccountCreateViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentCryptoTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [CryptoType], selectedType: CryptoType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func presentNetworkTypeSelection(from view: AccountCreateViewProtocol?, availableTypes: [SNAddressType], selectedType: SNAddressType, delegate: ModalPickerViewControllerDelegate?, context: AnyObject?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import Foundation


 class MockOnboardingMainViewProtocol: OnboardingMainViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainViewProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainViewProtocol
     typealias Verification = __VerificationProxy_OnboardingMainViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainViewProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    

	 struct __StubbingProxy_OnboardingMainViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockOnboardingMainViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	}

	 struct __VerificationProxy_OnboardingMainViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class OnboardingMainViewProtocolStub: OnboardingMainViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
}



 class MockOnboardingMainPresenterProtocol: OnboardingMainPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainPresenterProtocol
     typealias Verification = __VerificationProxy_OnboardingMainPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainPresenterProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func activateSignup()  {
        
    return cuckoo_manager.call("activateSignup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateSignup())
        
    }
    
    
    
     func activateAccountRestore()  {
        
    return cuckoo_manager.call("activateAccountRestore()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateAccountRestore())
        
    }
    
    
    
     func activateTerms()  {
        
    return cuckoo_manager.call("activateTerms()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activateTerms())
        
    }
    
    
    
     func activatePrivacy()  {
        
    return cuckoo_manager.call("activatePrivacy()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.activatePrivacy())
        
    }
    

	 struct __StubbingProxy_OnboardingMainPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func activateSignup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateSignup()", parameterMatchers: matchers))
	    }
	    
	    func activateAccountRestore() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateAccountRestore()", parameterMatchers: matchers))
	    }
	    
	    func activateTerms() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activateTerms()", parameterMatchers: matchers))
	    }
	    
	    func activatePrivacy() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainPresenterProtocol.self, method: "activatePrivacy()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func activateSignup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateSignup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateAccountRestore() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateAccountRestore()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activateTerms() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activateTerms()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func activatePrivacy() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("activatePrivacy()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainPresenterProtocolStub: OnboardingMainPresenterProtocol {
    

    

    
     func activateSignup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateAccountRestore()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activateTerms()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func activatePrivacy()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockOnboardingMainWireframeProtocol: OnboardingMainWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = OnboardingMainWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_OnboardingMainWireframeProtocol
     typealias Verification = __VerificationProxy_OnboardingMainWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: OnboardingMainWireframeProtocol?

     func enableDefaultImplementation(_ stub: OnboardingMainWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func showSignup(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showSignup(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showSignup(from: view))
        
    }
    
    
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)  {
        
    return cuckoo_manager.call("showAccountRestore(from: OnboardingMainViewProtocol?)",
            parameters: (view),
            escapingParameters: (view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showAccountRestore(from: view))
        
    }
    
    
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)  {
        
    return cuckoo_manager.call("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)",
            parameters: (url, view, style),
            escapingParameters: (url, view, style),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.showWeb(url: url, from: view, style: style))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_OnboardingMainWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showSignup(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(OnboardingMainViewProtocol?)> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showAccountRestore(from: OnboardingMainViewProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(URL, ControllerBackedProtocol, WebPresentableStyle)> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockOnboardingMainWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_OnboardingMainWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func showSignup<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showSignup(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showAccountRestore<M1: Cuckoo.OptionalMatchable>(from view: M1) -> Cuckoo.__DoNotUse<(OnboardingMainViewProtocol?), Void> where M1.OptionalMatchedType == OnboardingMainViewProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(OnboardingMainViewProtocol?)>] = [wrap(matchable: view) { $0 }]
	        return cuckoo_manager.verify("showAccountRestore(from: OnboardingMainViewProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func showWeb<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(url: M1, from view: M2, style: M3) -> Cuckoo.__DoNotUse<(URL, ControllerBackedProtocol, WebPresentableStyle), Void> where M1.MatchedType == URL, M2.MatchedType == ControllerBackedProtocol, M3.MatchedType == WebPresentableStyle {
	        let matchers: [Cuckoo.ParameterMatcher<(URL, ControllerBackedProtocol, WebPresentableStyle)>] = [wrap(matchable: url) { $0.0 }, wrap(matchable: view) { $0.1 }, wrap(matchable: style) { $0.2 }]
	        return cuckoo_manager.verify("showWeb(url: URL, from: ControllerBackedProtocol, style: WebPresentableStyle)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class OnboardingMainWireframeProtocolStub: OnboardingMainWireframeProtocol {
    

    

    
     func showSignup(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showAccountRestore(from view: OnboardingMainViewProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import fearless

import SoraFoundation


 class MockUsernameSetupViewProtocol: UsernameSetupViewProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupViewProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupViewProtocol
     typealias Verification = __VerificationProxy_UsernameSetupViewProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupViewProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupViewProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isSetup: Bool {
        get {
            return cuckoo_manager.getter("isSetup",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isSetup)
        }
        
    }
    
    
    
     var controller: UIViewController {
        get {
            return cuckoo_manager.getter("controller",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.controller)
        }
        
    }
    

    

    
    
    
     func set(viewModel: InputViewModelProtocol)  {
        
    return cuckoo_manager.call("set(viewModel: InputViewModelProtocol)",
            parameters: (viewModel),
            escapingParameters: (viewModel),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.set(viewModel: viewModel))
        
    }
    

	 struct __StubbingProxy_UsernameSetupViewProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSetup: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUsernameSetupViewProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup")
	    }
	    
	    
	    var controller: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockUsernameSetupViewProtocol, UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller")
	    }
	    
	    
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(InputViewModelProtocol)> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupViewProtocol.self, method: "set(viewModel: InputViewModelProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupViewProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSetup: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSetup", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var controller: Cuckoo.VerifyReadOnlyProperty<UIViewController> {
	        return .init(manager: cuckoo_manager, name: "controller", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func set<M1: Cuckoo.Matchable>(viewModel: M1) -> Cuckoo.__DoNotUse<(InputViewModelProtocol), Void> where M1.MatchedType == InputViewModelProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(InputViewModelProtocol)>] = [wrap(matchable: viewModel) { $0 }]
	        return cuckoo_manager.verify("set(viewModel: InputViewModelProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupViewProtocolStub: UsernameSetupViewProtocol {
    
    
     var isSetup: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    
    
     var controller: UIViewController {
        get {
            return DefaultValueRegistry.defaultValue(for: (UIViewController).self)
        }
        
    }
    

    

    
     func set(viewModel: InputViewModelProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUsernameSetupPresenterProtocol: UsernameSetupPresenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupPresenterProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupPresenterProtocol
     typealias Verification = __VerificationProxy_UsernameSetupPresenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupPresenterProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupPresenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func proceed()  {
        
    return cuckoo_manager.call("proceed()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed())
        
    }
    

	 struct __StubbingProxy_UsernameSetupPresenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupPresenterProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func proceed() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupPresenterProtocol.self, method: "proceed()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupPresenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func proceed() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("proceed()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupPresenterProtocolStub: UsernameSetupPresenterProtocol {
    

    

    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func proceed()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockUsernameSetupWireframeProtocol: UsernameSetupWireframeProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = UsernameSetupWireframeProtocol
    
     typealias Stubbing = __StubbingProxy_UsernameSetupWireframeProtocol
     typealias Verification = __VerificationProxy_UsernameSetupWireframeProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: UsernameSetupWireframeProtocol?

     func enableDefaultImplementation(_ stub: UsernameSetupWireframeProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func proceed(from view: UsernameSetupViewProtocol?, username: String)  {
        
    return cuckoo_manager.call("proceed(from: UsernameSetupViewProtocol?, username: String)",
            parameters: (view, username),
            escapingParameters: (view, username),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.proceed(from: view, username: username))
        
    }
    
    
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)",
            parameters: (message, title, closeAction, view),
            escapingParameters: (message, title, closeAction, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(message: message, title: title, closeAction: closeAction, from: view))
        
    }
    
    
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)  {
        
    return cuckoo_manager.call("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)",
            parameters: (viewModel, style, view),
            escapingParameters: (viewModel, style, view),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.present(viewModel: viewModel, style: style, from: view))
        
    }
    

	 struct __StubbingProxy_UsernameSetupWireframeProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, username: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(UsernameSetupViewProtocol?, String)> where M1.OptionalMatchedType == UsernameSetupViewProtocol, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(UsernameSetupViewProtocol?, String)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: username) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "proceed(from: UsernameSetupViewProtocol?, username: String)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(String?, String?, String?, ControllerBackedProtocol?)> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockUsernameSetupWireframeProtocol.self, method: "present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_UsernameSetupWireframeProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func proceed<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(from view: M1, username: M2) -> Cuckoo.__DoNotUse<(UsernameSetupViewProtocol?, String), Void> where M1.OptionalMatchedType == UsernameSetupViewProtocol, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(UsernameSetupViewProtocol?, String)>] = [wrap(matchable: view) { $0.0 }, wrap(matchable: username) { $0.1 }]
	        return cuckoo_manager.verify("proceed(from: UsernameSetupViewProtocol?, username: String)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(message: M1, title: M2, closeAction: M3, from view: M4) -> Cuckoo.__DoNotUse<(String?, String?, String?, ControllerBackedProtocol?), Void> where M1.OptionalMatchedType == String, M2.OptionalMatchedType == String, M3.OptionalMatchedType == String, M4.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(String?, String?, String?, ControllerBackedProtocol?)>] = [wrap(matchable: message) { $0.0 }, wrap(matchable: title) { $0.1 }, wrap(matchable: closeAction) { $0.2 }, wrap(matchable: view) { $0.3 }]
	        return cuckoo_manager.verify("present(message: String?, title: String?, closeAction: String?, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func present<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(viewModel: M1, style: M2, from view: M3) -> Cuckoo.__DoNotUse<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?), Void> where M1.MatchedType == AlertPresentableViewModel, M2.MatchedType == UIAlertController.Style, M3.OptionalMatchedType == ControllerBackedProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(AlertPresentableViewModel, UIAlertController.Style, ControllerBackedProtocol?)>] = [wrap(matchable: viewModel) { $0.0 }, wrap(matchable: style) { $0.1 }, wrap(matchable: view) { $0.2 }]
	        return cuckoo_manager.verify("present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from: ControllerBackedProtocol?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class UsernameSetupWireframeProtocolStub: UsernameSetupWireframeProtocol {
    

    

    
     func proceed(from view: UsernameSetupViewProtocol?, username: String)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
     func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}

