import SoraFoundation

final class EthereumDerivationPathProcessor: TextProcessing {
    func process(text: String) -> String {
        var resultString = String()
        for (index, component) in text.filter({ $0.isNumber }).enumerated() {
            switch index {
            case 0, 2, 4:
                resultString.append("//\(component)")
            case 5, 6:
                resultString.append("/\(component)")
            default:
                resultString.append(component.description)
            }
        }
        return resultString
    }
}
