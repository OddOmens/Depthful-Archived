import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showRestartAlert = false
    @State private var selectedLanguage: String = ""
    
    var body: some View {
        List {
            Section {
                ForEach(languageManager.availableLanguages, id: \.code) { language in
                    LanguageRow(
                        flag: language.flag,
                        name: language.name,
                        code: language.code,
                        isSelected: language.code == languageManager.currentLanguage
                    ) {
                        selectLanguage(language.code)
                    }
                }
            } header: {
                Text("Select Language".localized)
            } footer: {
                Text("The app will restart to apply the new language.".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .padding(5)
                    }
                }
            }
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) {
                // Reset to current language
                selectedLanguage = ""
            }
            Button("Restart App".localized) {
                // Apply the language change and restart
                languageManager.setLanguage(selectedLanguage)
                restartApp()
            }
        } message: {
            Text("The app needs to restart to apply the new language. Would you like to restart now?".localized)
        }
    }
    
    private func selectLanguage(_ languageCode: String) {
        if languageCode != languageManager.currentLanguage {
            selectedLanguage = languageCode
            showRestartAlert = true
        }
    }
    
    private func restartApp() {
        // Force app restart by exiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}

struct LanguageRow: View {
    let flag: String
    let name: String
    let code: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(flag)
                    .font(.title2)
                    .frame(width: 32)
                
                Text(name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                        .padding(5)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        LanguageSelectionView()
    }
} 
