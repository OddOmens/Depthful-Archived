import SwiftUI
import CoreData
import CloudKit

struct SettingsView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.managedObjectContext) private var viewContext
    
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var languageManager = LanguageManager.shared
    
    @Environment(\.openURL) var openURL
    
    @State private var showVersionView = false
    @State private var showAboutView = false
    @State private var showTermsView = false
    @State private var showPrivacyView = false
    @State private var showIconSelectionView = false
    @State private var showTagSelectionView = false
    @State private var showExportOptionsView = false
    @State private var showImportOptionsView = false
    @State private var showDeleteConfirmationAlert = false
    
    @ObservedObject var tagManager: TagManager
    @State private var showTagSelection = false
    
    var body: some View {
        List {
            Section(header: Text("Customize".localized).padding(.horizontal, 10).padding(.vertical, 5).glassEffect()) {
                HStack {
                    Image("lightbulb-alt-on")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(Color.colorPrimary)
                    
                    Text("Appearance".localized)
                    
                    Spacer()
                    
                    Picker("", selection: $themeManager.currentTheme) {
                        Text("System".localized)
                            .foregroundColor(.primary)
                            .tag(ThemeManager.ThemeType.system)
                        Text("Light".localized)
                            .foregroundColor(.primary)
                            .tag(ThemeManager.ThemeType.light)
                        Text("Dark".localized)
                            .foregroundColor(.primary)
                            .tag(ThemeManager.ThemeType.dark)
                    }
                    .pickerStyle(.menu)
                    .accentColor(.primary)
                }
                .padding(.vertical, 4)
                
                NavigationLink {
                    LanguageSelectionView()
                } label: {
                    HStack {
                        Image("globe")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Language".localized)
                        
                        Spacer()
                        
                        Text(languageManager.currentLanguageDisplayName)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink {
                    IconPickerView()
                } label: {
                    HStack {
                        Image("glasses")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Custom App Icon".localized)
                    }
                }
            }
            
            Section(header: Text("Manage Thoughts".localized).padding(.horizontal, 10).padding(.vertical, 5).glassEffect()) {
                NavigationLink {
                    ExportOptionsView(thought: nil)
                        .environment(\.managedObjectContext, viewContext)
                } label: {
                    HStack {
                        Image("file-arrow-up-alt")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Export Thoughts".localized)
                    }
                }
                
                
                NavigationLink {
                    ImportOptionsView()
                        .environment(\.managedObjectContext, viewContext)
                } label: {
                    HStack {
                        Image("file-arrow-up-alt")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Import Thoughts".localized)
                    }
                }
                
                
                Button(action: {
                    showDeleteConfirmationAlert = true
                }) {
                    HStack {
                        Image("file-shredder")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Delete Thoughts".localized)
                    }
                }
            }
            
            Section(header: Text("Help".localized).padding(.horizontal, 10).padding(.vertical, 5).glassEffect()) {
                Button(action: {
                    openURL(URL(string: "https://docs.oddomens.com")!)
                }) {
                    HStack {
                        Image("message-square-info")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        Text("Documentation")

                    }
                }
                
                Button(action: {
                    // Define your mailto URL with subject and body
                    let emailSubject = "Depthful - App Support"
                    let emailBody = "Hello, I need help with..."
                    let emailAddress = "support@oddomens.com"
                    
                    // URL encode the subject and body to ensure special characters are handled correctly
                    let encodedSubject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    
                    // Construct the full mailto URL
                    let mailtoURL = URL(string: "mailto:\(emailAddress)?subject=\(encodedSubject)&body=\(encodedBody)")!
                    
                    // Attempt to open the URL
                    openURL(mailtoURL)
                }) {
                    HStack {
                        Image("mail")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        
                        Text("Email Support".localized)
                    }
                }
                
                Button(action: {
                    // Define your mailto URL with subject and body
                    let emailSubject = "Depthful - Report an Issue"
                    let emailBody = "Please describe the issue you're experiencing..."
                    let emailAddress = "support@oddomens.com"

                    // URL encode the subject and body to ensure special characters are handled correctly
                    let encodedSubject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                    // Construct the full mailto URL
                    let mailtoURL = URL(string: "mailto:\(emailAddress)?subject=\(encodedSubject)&body=\(encodedBody)")!

                    // Attempt to open the URL
                    openURL(mailtoURL)
                }) {
                    HStack {
                        Image("message-square-info")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        Text("Report an Issue")
                    }
                }
                
                Button(action: {
                    // Define your mailto URL with subject and body
                    let emailSubject = "Depthful - Feature Request"
                    let emailBody = "I would like to request the following feature..."
                    let emailAddress = "support@oddomens.com"

                    // URL encode the subject and body to ensure special characters are handled correctly
                    let encodedSubject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                    // Construct the full mailto URL
                    let mailtoURL = URL(string: "mailto:\(emailAddress)?subject=\(encodedSubject)&body=\(encodedBody)")!

                    // Attempt to open the URL
                    openURL(mailtoURL)
                }) {
                    HStack {
                        Image("message-square-question")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)
                        Text("Request a Feature")
                    }
                }

            }
            
            Section(header: Text("About Depthful".localized).padding(.horizontal, 10).padding(.vertical, 5).glassEffect()) {
                Button(action: {
                    openURL(URL(string: "https://apps.apple.com/us/app/depthful/id6479280808")!)
                }) {
                    HStack {
                        Image("star")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)


                        Text("Rate Depthful".localized)
                    }
                }

                NavigationLink {
                    VersionView()
                } label: {
                    HStack {
                        Image("certificate-check") // Symbol for About
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)


                        Text("Version".localized)
                        Text("2025.12.1")
                    }
                }
            }
            
            Section(header: Text("Privacy and Terms".localized).padding(.horizontal, 10).padding(.vertical, 5).glassEffect()) {
                Button(action: {
                    openURL(URL(string: "https://oddomens.com/privacy")!)
                }){
                    HStack {
                        Image("memo-check")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)

                        Text("Privacy Policy".localized)
                    }
                }

                Button(action: {
                    openURL(URL(string: "https://oddomens.com/terms")!)
                }){
                    HStack {
                        Image("memo-check")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(Color.colorPrimary)

                        Text("Terms of Service".localized)
                    }
                }
            }
        }
        .listStyle(.inset)
        .alert(isPresented: $showDeleteConfirmationAlert) {
            Alert(
                title: Text("Confirm Deletion".localized),
                message: Text("Are you sure you want to delete all thoughts? This action cannot be undone.".localized),
                primaryButton: .destructive(Text("Delete All".localized)) {
                    deleteAllThoughts()
                },
                secondaryButton: .cancel(Text("Cancel".localized))
            )
        }
        .navigationTitle("Settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image("arrow-left")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.colorPrimary)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        
                }
            }
        }
    }
    
    private func deleteAllThoughts() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Thought.fetchRequest()
        
        do {
            let thoughts = try viewContext.fetch(fetchRequest)
            for case let thought as NSManagedObject in thoughts {
                viewContext.delete(thought)
            }
            try viewContext.save()
        } catch {
            print("Failed to delete all thoughts: \(error)")
        }
    }
}
