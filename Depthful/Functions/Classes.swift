import SwiftUI
import Foundation

func incrementAppLaunchCount() {
    let defaults = UserDefaults.standard
    let launchCount = defaults.integer(forKey: "launchCount") + 1
    defaults.set(launchCount, forKey: "launchCount")
}


extension UIApplication {
    var foregroundActiveScene: UIWindowScene? {
        connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    }
}
