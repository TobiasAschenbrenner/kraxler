import SwiftUI

struct MapAreaMarker: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(KraxlerDesign.accent.opacity(0.22))
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(KraxlerDesign.accent, lineWidth: 3)
                    .frame(width: 22, height: 22)
            }

            Circle()
                .fill(KraxlerDesign.accent)
                .frame(width: isSelected ? 12 : 11, height: isSelected ? 12 : 11)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.38), radius: 4, y: 1)
        }
        .frame(width: 34, height: 34)
        .animation(.snappy(duration: 0.22), value: isSelected)
    }
}
