import Foundation

class AppVersionComparator {
    
    func isCurrentVersionLowerThanMinimal(currentVersion: String, minimalVersion: String) -> Bool {
        let currentVersionComponents = currentVersion.components(separatedBy: ".")
        let minimalVersionComponents = minimalVersion.components(separatedBy: ".")
        
        let comparableComponentsCount = min(currentVersionComponents.count, minimalVersionComponents.count)
        
        for i in 0...comparableComponentsCount - 1 {
            let currentVersionComponent = currentVersionComponents[i]
            let minimalVersionComponent = minimalVersionComponents[i]
            
            if currentVersionComponent < minimalVersionComponent {
                return true
            }
        }
        
        return false
    }
}
