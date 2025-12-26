import SwiftUI
import StoreKit
import WidgetKit

// Define deep link types for App Events
enum DeepLinkType: String, CaseIterable {
    case languages = "languages"
    case voiceNotes = "voice-notes"
    
    var displayName: String {
        switch self {
        case .languages:
            return "Language Settings"
        case .voiceNotes:
            return "Voice Notes"
        }
    }
}

@main
struct DepthfulApp: App {
    @AppStorage("launchCount") private var launchCount = 0
    @AppStorage("reviewPromptLastShown") private var reviewPromptLastShown = 0
    @AppStorage("userChoseToReviewLater") private var userChoseToReviewLater = false
    @AppStorage("userDeclinedToReview") private var userDeclinedToReview = false
    
    // Add states for widget URL handling
    @State private var navigateToNewThought = false
    @State private var thoughtIdToOpen: URL?
    
    // Add state for App Event deeplinks
    @State private var deepLinkReceived = false
    @State private var deepLinkType: DeepLinkType?
    
    // Add state for persistence error handling
    @State private var showingPersistenceError = false
    @State private var persistenceErrorMessage = ""
    
    let persistenceController = PersistenceController.shared
    
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    init() {
        incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Show different view depending on persistence state
                if let error = persistenceController.persistenceLoadError {
                    PersistenceErrorView(
                        error: error,
                        showingPersistenceError: $showingPersistenceError,
                        persistenceErrorMessage: $persistenceErrorMessage
                    )
                    .onAppear {
                        persistenceErrorMessage = error.localizedDescription
                        showingPersistenceError = true
                    }
                } else {
                    NavigationStack {
                        ThoughtsView(shouldCreateNewThought: navigateToNewThought, thoughtURLToOpen: thoughtIdToOpen)
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(purchaseManager)
                            .onOpenURL { url in
                                handleDeepLink(url)
                            }
                            .alert("App Event", isPresented: $deepLinkReceived) {
                                Button("OK") {
                                    deepLinkReceived = false
                                    deepLinkType = nil
                                }
                            } message: {
                                if let deepLinkType = deepLinkType {
                                    Text("Opened from \(deepLinkType.displayName) App Event")
                                }
                            }
                            .task {
                                // Check subscription status on launch
                                await purchaseManager.checkSubscriptionStatus()

                                // Apply theme and check for prompts after subscription check
                                themeManager.applyTheme()

                                // Check review prompt
                                checkAndPromptForReview()
                            }
                    }
                }
            }
        }
    }
    
    private func incrementLaunchCount() {
        launchCount += 1
    }
    
    private func checkAndPromptForReview() {
        if launchCount == 2 || launchCount == 5 {
            DispatchQueue.main.async {
                guard let scene = UIApplication.shared.foregroundActiveScene else { return }

                if #available(iOS 18.0, *) {
                    // Use new AppStore API for iOS 18+
                    AppStore.requestReview(in: scene)
                } else {
                    // Fallback for older iOS versions
                    SKStoreReviewController.requestReview(in: scene)
                }

                reviewPromptLastShown = launchCount
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("Deep link received: \(url)")
        
        // Handle different URL schemes
        guard let scheme = url.scheme else { return }
        
        switch scheme {
        case "depthful":
            // Handle depthful:// URLs for App Events
            let path = url.host ?? url.pathComponents.first ?? ""
            
            if let deepLinkType = DeepLinkType(rawValue: path) {
                print("App Event deep link detected: \(deepLinkType.displayName)")
                
                // Set state to indicate deep link was received
                deepLinkReceived = true
                self.deepLinkType = deepLinkType
                
                // For now, just open the app - you can add specific navigation later
                // The app is already opening by receiving the URL
                
            } else {
                print("Unknown deep link path: \(path)")
            }
            
        default:
            print("Unsupported URL scheme: \(scheme)")
        }
    }
}

// Add a view to handle persistence errors gracefully
struct PersistenceErrorView: View {
    let error: Error
    @Binding var showingPersistenceError: Bool
    @Binding var persistenceErrorMessage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.bottom, 10)
            
            Text("Database Access Issue".localized)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("We're having trouble accessing your data.".localized)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(persistenceErrorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Your data is safe! The app is currently running in limited functionality mode.".localized)
                .font(.callout)
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 10)
            
            VStack(spacing: 15) {
                Button(action: {
                    // Try to restart the app programmatically
                    exit(0)
                }) {
                    Text("Restart App".localized)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Hide the error message and try to continue in limited mode
                    showingPersistenceError = false
                }) {
                    Text("Continue in Limited Mode".localized)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20)
        )
        .padding(.horizontal, 30)
    }
}
