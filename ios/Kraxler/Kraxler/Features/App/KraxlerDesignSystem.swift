import SwiftUI

enum KraxlerDesign {
    static let accent = Color.orange
    static let success = Color.green
    static let pagePadding: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let compactRadius: CGFloat = 14
}

struct KraxlerScreenBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    KraxlerDesign.accent.opacity(0.16),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

struct KraxlerBrandMark: View {
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: "mountain.2.fill")
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(KraxlerDesign.accent.gradient, in: RoundedRectangle(cornerRadius: size * 0.28))
            .shadow(color: KraxlerDesign.accent.opacity(0.24), radius: 16, y: 8)
            .accessibilityHidden(true)
    }
}

struct KraxlerSettingsLabel: View {
    let title: String
    let systemImage: String
    var color: Color = KraxlerDesign.accent

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 24)
        }
    }
}

extension View {
    @ViewBuilder
    func kraxlerGlassSurface(
        cornerRadius: CGFloat = KraxlerDesign.cardRadius,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                glassEffect(
                    .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
    }

    func kraxlerCard() -> some View {
        padding()
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: KraxlerDesign.cardRadius)
            )
    }
}

struct KraxlerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                KraxlerDesign.accent.opacity(configuration.isPressed ? 0.76 : 1),
                in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
