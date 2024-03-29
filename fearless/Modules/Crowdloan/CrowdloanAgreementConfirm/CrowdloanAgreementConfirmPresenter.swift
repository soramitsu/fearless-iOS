import Foundation
import FearlessUtils
import SoraFoundation
import BigInt
import SwiftUI

final class CrowdloanAgreementConfirmPresenter: CrowdloanAgreementConfirmInteractorOutputProtocol {
    weak var view: CrowdloanAgreementConfirmViewProtocol?
    let wireframe: CrowdloanAgreementConfirmWireframeProtocol
    let interactor: CrowdloanAgreementConfirmInteractorInputProtocol
    let chain: Chain
    let logger: LoggerProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let agreementViewModelFactory: CrowdloanAgreementViewModelFactoryProtocol

    private var paraId: ParaId
    private var displayAddress: DisplayAddress?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var customFlow: CustomCrowdloanFlow

    init(
        interactor: CrowdloanAgreementConfirmInteractorInputProtocol,
        wireframe: CrowdloanAgreementConfirmWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        agreementViewModelFactory: CrowdloanAgreementViewModelFactoryProtocol,
        chain: Chain,
        logger: LoggerProtocol,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.agreementViewModelFactory = agreementViewModelFactory
        self.chain = chain
        self.logger = logger
        self.paraId = paraId
        self.customFlow = customFlow
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func provideAccountViewModel() {
        guard let displayAddress = displayAddress else {
            return
        }

        let accountViewModel = try? agreementViewModelFactory.createAccountViewModel(from: displayAddress)
        view?.didReceiveAccount(viewModel: accountViewModel)
    }
}

extension CrowdloanAgreementConfirmPresenter: CrowdloanAgreementConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func confirmAgreement() {
        view?.didReceive(state: .confirmLoading)

        interactor.confirmAgreement()
    }
}

extension CrowdloanAgreementConfirmPresenter {
    func didReceiveVerifiedExtrinsicHash(result: Result<String, Error>) {
        view?.didReceive(state: .normal)

        switch result {
        case let .success(hash):
            wireframe.showAgreementSigned(
                from: view,
                paraId: paraId,
                remarkExtrinsicHash: hash,
                customFlow: customFlow
            )

        case let .failure(error):
            _ = wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            )

            logger.error("Did receive verify remark error: \(error)")
        }
    }

    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>) {
        switch result {
        case let .success(displayAddress):
            self.displayAddress = displayAddress

            provideAccountViewModel()
        case let .failure(error):
            logger.error("Did receive account item error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision)
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive price error: \(error)")
        }
    }
}

extension CrowdloanAgreementConfirmPresenter: Localizable {
    func applyLocalization() {}
}
