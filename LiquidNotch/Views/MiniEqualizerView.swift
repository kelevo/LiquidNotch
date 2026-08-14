import SwiftUI

struct MiniEqualizerView: View {
    let isPlaying: Bool
    let barCount = 14

    var body: some View {
        Group {
            if isPlaying {
                TimelineView(.animation(minimumInterval: 0.04)) { timeline in
                    barsView(date: timeline.date)
                }
            } else {
                barsView(date: .distantPast)
            }
        }
        .frame(height: 16)
    }

    private func barsView(date: Date) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2, height: barHeight(for: index, at: date))
            }
        }
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        guard isPlaying else { return 3 }

        let time = date.timeIntervalSinceReferenceDate * 5.0
        let center = Double(barCount - 1) / 2.0
        let distFromCenter = abs(Double(index) - center) / center
        let envelope = 1.0 - (distFromCenter * 0.4)

        let wave1 = sin(time * 1.8 + Double(index) * 0.8)
        let wave2 = cos(time * 2.6 - Double(index) * 1.1)
        let wave3 = sin(time * 3.4 + Double(index) * 0.5)

        let combined = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2 + 1.0) / 2.0
        let dynamicHeight = 3.0 + combined * 13.0 * envelope

        return CGFloat(min(max(dynamicHeight, 3), 16))
    }
}
