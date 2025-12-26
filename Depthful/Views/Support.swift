import SwiftUI
import CoreData
import UIKit
import StoreKit

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var hasActiveSubscription = false
    @Published var hasContributed = false
    
    private let productIdentifiers = [
        "Breatheful_Monthly_Support",
        "Breatheful_OneTime_Support"
    ]
    
    init() {
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    @MainActor
    func checkSubscriptionStatus() async {
        do {
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                if transaction.productID == "Breatheful_Monthly_Support" {
                    hasActiveSubscription = true
                }
                if transaction.productID == "Breatheful_OneTime_Support" {
                    hasContributed = true
                }
            }
        } catch {
            print("Failed to verify transaction: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
        case .pending:
            print("Purchase pending")
        case .userCancelled:
            print("User cancelled")
        @unknown default:
            break
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

// Add a helper method to check subscription status
extension PurchaseManager {
    func hasFullAccess() -> Bool {
        return true
    }
    
    func isLifetimeMember() -> Bool {
        return false
    }
}

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: DonationPlan?
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    enum DonationPlan {
        case monthly
        case oneTime
        
        var title: String {
            switch self {
            case .monthly: return "Monthly Support"
            case .oneTime: return "One-time Support"
            }
        }
        
        var price: String {
            return "$1.99"
        }
        
        var description: String {
            switch self {
            case .monthly: return "Support development every month"
            case .oneTime: return "Single contribution to development"
            }
        }
        
        var productId: String {
            switch self {
            case .monthly: return "Breatheful_Monthly_Support"
            case .oneTime: return "Breatheful_OneTime_Support"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header with subscription status
                    headerSection
                    
                    // What your support enables
                    featuresSection
                    
                    // Donation Options
                    subscriptionOptionsSection
                    
                    // Support Button
                    supportButtonSection
                    
                    // Thank you note
                    Text("Thank you for considering supporting this app! ❤️")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Terms
                    termsSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Support Development")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color("AccentColor"))
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if purchaseManager.hasActiveSubscription {
                activeSubscriptionBanner
            } else if purchaseManager.hasContributed {
                contributionBanner
            }
            
            Text("Breatheful will always be free and will never have ads. Your contribution isn't required but does help me continue development.")
                .foregroundColor(Color("AccentColor"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var activeSubscriptionBanner: some View {
        VStack {
            Text("Thank you for your monthly support! ❤️")
                .foregroundColor(Color("AccentColor"))
                .font(.headline)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("AccentColor").opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("AccentColor"), lineWidth: 1.5)
        )
        .cornerRadius(16)
    }
    
    private var contributionBanner: some View {
        VStack {
            Text("Thank you for your support! ❤️")
                .foregroundColor(.red)
                .font(.headline)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("AccentColor"), lineWidth: 1.5)
        )
        .cornerRadius(16)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Support Enables")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "sparkles", text: "New features and improvements")
                FeatureRow(icon: "wrench.and.screwdriver", text: "Regular app maintenance")
                FeatureRow(icon: "bubble.left.and.bubble.right", text: "Better user support")
                FeatureRow(icon: "heart", text: "Independent development")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 16) {
            // Monthly Support
            SubscriptionButton(
                title: DonationPlan.monthly.title,
                price: DonationPlan.monthly.price,
                description: DonationPlan.monthly.description,
                isSelected: selectedPlan == .monthly,
                action: { selectedPlan = .monthly }
            )
            
            // One-time Support
            SubscriptionButton(
                title: DonationPlan.oneTime.title,
                price: DonationPlan.oneTime.price,
                description: DonationPlan.oneTime.description,
                isSelected: selectedPlan == .oneTime,
                action: { selectedPlan = .oneTime }
            )
        }
        .padding(.horizontal)
    }
    
    private var supportButtonSection: some View {
        Button(action: {
            if let selected = selectedPlan {
                Task {
                    do {
                        if let product = try await Product.products(for: [selected.productId]).first {
                            try await PurchaseManager.shared.purchase(product)
                            dismiss()
                        }
                    } catch {
                        print("Support purchase failed: \(error)")
                    }
                }
            }
        }) {
            supportButtonLabel
        }
        .disabled(selectedPlan == nil)
        .padding(.horizontal)
        .opacity(selectedPlan == nil ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: selectedPlan)
    }
    
    private var supportButtonLabel: some View {
        // Extract the button text logic to a separate function
        let buttonText = getButtonText()
        
        // Create the background separately
        let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Build the text view first
        let textView = Text(buttonText)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        
        // Apply styling to the text view
        return textView
            .background(backgroundGradient)
            .cornerRadius(16)
            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
    }
    
    // Helper function to determine button text
    private func getButtonText() -> String {
        if selectedPlan == .oneTime {
            return purchaseManager.hasContributed ? "Support Again" : "Support Now"
        } else {
            return purchaseManager.hasActiveSubscription ? "Update Monthly Support" : "Support Monthly"
        }
    }
    
    private var termsSection: some View {
        VStack(spacing: 12) {
            if selectedPlan == .monthly {
                Text("Monthly support automatically renews unless cancelled at least 24-hours before the end of the current period.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .animation(.easeInOut, value: selectedPlan)
            }
            
            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical)
    }
}

struct SubscriptionButton: View {
    let title: String
    let price: String
    let description: String
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(price)
                        .font(.title3)
                        .bold()
                        .foregroundColor(isSelected ? Color("AccentColor") : .primary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(isSelected ? Color("AccentColor").opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color("AccentColor") : Color("AccentColor"),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(Color("AccentColor"))
                .font(.system(size: 18))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color("AccentColor").opacity(0.1))
                        .frame(width: 36, height: 36)
                )
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

