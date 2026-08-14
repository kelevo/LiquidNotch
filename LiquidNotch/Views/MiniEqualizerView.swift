import SwiftUI

struct MiniEqualizerView: View {
    let isPlaying: Bool
    let barCount = 5

    var body: some View {
        Group {
            if isPlaying {
                TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                    barsView(date: timeline.date)
                }
            } else {
                barsView(date: .distantPast)
            }
        }
        .frame(height: 16)
        .opacity(isPlaying ? 1 : 0.3)
    }

    private func barsView(date: Date) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: barHeight(for: index, at: date))
            }
        }
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        guard isPlaying else { return 4 }

        let time = date.timeIntervalSinceReferenceDate
        let phase = Double(index) * 0.8
        let wave = sin(time * 4 + phase)
        let normalized = (wave + 1) / 2
        return CGFloat(4 + normalized * 12)
    }
}
