import SwiftUI

struct AudioWaveformView: View {
    let isPlaying: Bool
    let progress: Double // 0.0 to 1.0
    
    private let numberOfBars = 35
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<numberOfBars, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: barWidth(in: geometry.size.width),
                               height: barHeight(for: index))
                }
            }
        }
    }
    
    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = barSpacing * CGFloat(numberOfBars - 1)
        return (totalWidth - totalSpacing) / CGFloat(numberOfBars)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let heightMultiplier = Double.random(in: 0.3...1.0)
        return 20 * heightMultiplier
    }
    
    private func barColor(for index: Int) -> Color {
        let position = Double(index) / Double(numberOfBars)
        if position <= progress {
            return Color.colorPrimary
        } else {
            return Color.gray.opacity(0.3)
        }
    }
} 