import Foundation

extension String {
    func versionLowerThan(_ minimalVersion: String?) -> Bool {
        guard let minimalVersion = minimalVersion else {
            return false
        }

        let currentVersion = self

        let currentVersionComponents = currentVersion.components(separatedBy: ".")
        let minimalVersionComponents = minimalVersion.components(separatedBy: ".")

        let comparableComponentsCount = min(currentVersionComponents.count, minimalVersionComponents.count)

        for index in 0 ... comparableComponentsCount - 1 {
            if let currentVersionComponent = Int(currentVersionComponents[index]),
               let minimalVersionComponent = Int(minimalVersionComponents[index]) {
                return currentVersionComponent < minimalVersionComponent
            } else {
                return false
            }
        }

        return false
    }
}
