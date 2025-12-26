import SwiftUI

struct MediaIndicatorView: View {
    let imageCount: Int
    let recordingCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Image count
            HStack(spacing: 4) {
                Image(systemName: "photo.fill")
                    .foregroundColor(imageCount > 0 ? Color.colorPrimary : Color.gray.opacity(0.5))
                Text("\(imageCount)".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Recording count
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .foregroundColor(recordingCount > 0 ? Color.colorPrimary : Color.gray.opacity(0.5))
                Text("\(recordingCount)".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
} 