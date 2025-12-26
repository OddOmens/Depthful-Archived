import SwiftUI
import Combine
import Foundation

class ThemeManager: ObservableObject {
    
    enum ThemeType: String, CaseIterable, Identifiable {
        case system, light, dark
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .system:
                return "System"
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            }
        }
    }
    
    @Published var currentTheme: ThemeType {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "theme")
            applyTheme()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "theme"),
           let theme = ThemeType(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            currentTheme = .system
        }
        
        // Listen for system appearance changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
        
        // Listen for trait collection changes (dark/light mode toggles)
        NotificationCenter.default.publisher(for: NSNotification.Name("traitCollectionDidChange"))
            .sink { [weak self] _ in
                if self?.currentTheme == .system {
                    self?.applyTheme()
                }
            }
            .store(in: &cancellables)
        
        applyTheme()
    }
    
    func applyTheme() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            switch currentTheme {
            case .light:
                windowScene.windows.first?.overrideUserInterfaceStyle = .light
            case .dark:
                windowScene.windows.first?.overrideUserInterfaceStyle = .dark
            case .system:
                windowScene.windows.first?.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

