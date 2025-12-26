import SwiftUI

class IconManager: ObservableObject {
    static let shared = IconManager()
    
    @Published var icons: [AppIcon] = [
        AppIcon(name: "Default", description: "Classic vibes for your mental drive.", imageName: "AppIcon"),
        AppIcon(name: "Morning", description: "Start fresh with a bright session.", imageName: "AppIconMorning"),
        AppIcon(name: "Midnight", description: "Calm thoughts for late-night insights.", imageName: "AppIconMidnight"),
        AppIcon(name: "Winter", description: "Chill and think, it's therapeutic.", imageName: "AppIconWinter"),
        AppIcon(name: "Charcoal", description: "Bold sessions for intense reflections.", imageName: "AppIconCharcoal"),
        AppIcon(name: "Norse", description: "Rugged like therapy for the soul.", imageName: "AppIconNorse"),
        AppIcon(name: "Seaweed", description: "Deep and calm like an ocean's balm.", imageName: "AppIconSeaweed"),
        AppIcon(name: "Mint", description: "Fresh thoughts for a minty mindset.", imageName: "AppIconMint"),
        AppIcon(name: "Cherry Blossom", description: "Bloom your thoughts, feel the spring.", imageName: "AppIconCherryBlossom"),
        AppIcon(name: "Blueberry", description: "Sweet ideas for a fruitful mind.", imageName: "AppIconBlueberry")
    ]
    @Published var currentIcon: String?
    
    init() {
        currentIcon = UserDefaults.standard.string(forKey: "selectedIconName")
    }
}

struct AppIcon: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String
    
    static func == (lhs: AppIcon, rhs: AppIcon) -> Bool {
        lhs.id == rhs.id
    }
}

struct IconView: View {
    let icon: AppIcon
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image("Preview" + icon.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .cornerRadius(15)
            VStack(alignment: .leading) {
                Text(icon.name)
                    .font(.headline)
                Text(icon.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color("AccentColor"))
            }
        }
    }
}

struct IconPickerView: View {
    @StateObject private var iconManager = IconManager.shared
    @State private var selectedIcon: AppIcon?
    @State private var isIconChangeSuccessful = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(iconManager.icons) { icon in
                    Button(action: {
                        selectedIcon = icon
                        setAppIcon(to: icon.imageName == "AppIcon" ? nil : icon.imageName) { success in
                            if success {
                                isIconChangeSuccessful = true
                                UserDefaults.standard.setValue(icon.imageName, forKey: "selectedIconName")
                            } else {
                                isIconChangeSuccessful = false
                                selectedIcon = nil
                            }
                        }
                    }) {
                        IconView(icon: icon, isSelected: selectedIcon == icon && isIconChangeSuccessful)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationBarTitle("App Icons", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done".localized)
                    .foregroundColor(Color("AccentColor"))
            }
        )
        .onAppear {
            if let savedIconName = UserDefaults.standard.string(forKey: "selectedIconName"),
               let savedIcon = iconManager.icons.first(where: { $0.imageName == savedIconName }) {
                selectedIcon = savedIcon
                isIconChangeSuccessful = true
            }
        }
    }
}

func setAppIcon(to iconName: String?, completion: @escaping (Bool) -> Void) {
    guard UIApplication.shared.supportsAlternateIcons else {
        completion(false)
        return
    }
    
    UIApplication.shared.setAlternateIconName(iconName) { error in
        DispatchQueue.main.async {
            if let error = error {
                print("Error setting alternate icon: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Successfully changed app icon to: \(iconName ?? "default")")
                completion(true)
            }
        }
    }
}
