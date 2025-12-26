import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            Bundle.setLanguage(currentLanguage)
        }
    }
    
    // Available languages with their details
    let availableLanguages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("de", "Deutsch", "🇩🇪"),
        ("es", "Español", "🇪🇸"),
        ("zh-Hans", "中文 (简体)", "🇨🇳"),
        ("hi", "हिन्दी", "🇮🇳"),
        ("fr", "Français", "🇫🇷"),
        ("pt", "Português", "🇵🇹"),
        ("ko", "한국어", "🇰🇷")
    ]
    
    var currentLanguageDisplayName: String {
        return availableLanguages.first { $0.code == currentLanguage }?.name ?? "English"
    }
    
    var currentLanguageFlag: String {
        return availableLanguages.first { $0.code == currentLanguage }?.flag ?? "🇺🇸"
    }
    
    private init() {
        // Get saved language or default to system language
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            self.currentLanguage = savedLanguage
        } else {
            // Default to English if system language is not supported
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            let supportedCodes = availableLanguages.map { $0.code }
            self.currentLanguage = supportedCodes.contains(systemLanguage) ? systemLanguage : "en"
        }
        
        Bundle.setLanguage(currentLanguage)
    }
    
    func setLanguage(_ languageCode: String) {
        currentLanguage = languageCode
    }
}

// Bundle extension to handle language switching
extension Bundle {
    private static var bundle: Bundle = Bundle.main
    
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, AnyLanguageBundle.self)
        }
        
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if language not found
            Bundle.bundle = Bundle.main
            return
        }
        
        Bundle.bundle = bundle
    }
    
    static func localizedString(forKey key: String, value: String? = nil, table: String? = nil) -> String {
        return Bundle.bundle.localizedString(forKey: key, value: value, table: table)
    }
}

class AnyLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = Bundle.main.path(forResource: LanguageManager.shared.currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// String extension for easy localization
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
} 