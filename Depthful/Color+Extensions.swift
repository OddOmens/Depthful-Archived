import SwiftUI
import UIKit

extension Color {
    var isDark: Bool {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        // Extract the RGBA components. If extraction fails, assume the color is not dark.
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }
        
        // Calculate brightness using the standard formula.
        // Typically, brightness < 0.5 is considered dark.
        let brightness = (0.299 * red + 0.587 * green + 0.114 * blue)
        return brightness < 0.5
    }
} 