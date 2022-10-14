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

        var componentIndex = 0
        func validateComponent(currentVersion: Int, minimalVersion: Int) -> Bool {
            if currentVersion < minimalVersion {
                return true
            } else if currentVersion > minimalVersion {
                return false
            } else {
                componentIndex += 1
                guard componentIndex < comparableComponentsCount,
                      let currentComponent = Int(currentVersionComponents[componentIndex]),
                      let minimalComponent = Int(minimalVersionComponents[componentIndex]) else {
                    return false
                }
                return validateComponent(
                    currentVersion: currentComponent,
                    minimalVersion: minimalComponent
                )
            }
        }

        return false
    }
}
