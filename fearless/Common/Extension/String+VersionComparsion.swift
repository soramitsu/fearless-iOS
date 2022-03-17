import Foundation

extension String {
    func versionLowerThan(_ minimalVersion: String) -> Bool {
        let currentVersion = self

        let currentVersionComponents = currentVersion.components(separatedBy: ".")
        let minimalVersionComponents = minimalVersion.components(separatedBy: ".")

        let comparableComponentsCount = min(currentVersionComponents.count, minimalVersionComponents.count)

        for index in 0 ... comparableComponentsCount - 1 {
            let currentVersionComponent = currentVersionComponents[index]
            let minimalVersionComponent = minimalVersionComponents[index]

            if currentVersionComponent < minimalVersionComponent {
                return true
            }
        }

        return false
    }
}
