import SwiftUI

enum KraxlerDesign {
    static let accent = Color(red: 0.08, green: 0.68, blue: 0.94)
    static let warning = Color.red
    static let sectionBackground = Color(.secondarySystemBackground)
    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let compactRadius: CGFloat = 16
    static let controlSize: CGFloat = 52
}

struct KraxlerScreenBackground: View {
    var showsTopography = false

    var body: some View {
        ZStack {
            Color(.systemBackground)

            if showsTopography {
                KraxlerTopographicPattern()
            }
        }
        .ignoresSafeArea()
    }
}

struct KraxlerBrandMark: View {
    var size: CGFloat = 52

    var body: some View {
        Image("KraxlerMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size * 0.42)
            .accessibilityHidden(true)
    }
}

private struct KraxlerTopographicPattern: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            Image("TerrainContours")
                .renderingMode(.template)
                .resizable()
                .scaledToFill()
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                .opacity(colorScheme == .dark ? 0.28 : 0.16)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
        }
        .allowsHitTesting(false)
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
    func kraxlerGlassSurface(
        cornerRadius: CGFloat = KraxlerDesign.cardRadius,
        interactive: Bool = false
    ) -> some View {
        glassEffect(
            interactive
                ? .regular.tint(.white.opacity(0.06)).interactive()
                : .regular,
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    func kraxlerCard() -> some View {
        padding()
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: KraxlerDesign.cardRadius)
            )
    }
}

struct KraxlerPrimaryButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(labelColor)
            .tint(labelColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                backgroundColor.opacity(0.96),
                in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        if !isEnabled, prominent {
            return colorScheme == .dark
                ? Color(red: 149 / 255, green: 149 / 255, blue: 158 / 255)
                : Color(red: 232 / 255, green: 232 / 255, blue: 238 / 255)
        }

        if prominent {
            return colorScheme == .dark
                ? Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
                : Color(.systemGray5)
        }

        return Color(.secondarySystemBackground)
    }

    private var labelColor: Color {
        guard isEnabled else {
            if prominent {
                return colorScheme == .dark
                    ? Color(red: 72 / 255, green: 72 / 255, blue: 79 / 255)
                    : Color(red: 133 / 255, green: 133 / 255, blue: 140 / 255)
            }

            return .secondary
        }

        return prominent ? .black : .primary
    }
}

struct KraxlerIconButtonStyle: ButtonStyle {
    var foregroundStyle: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(foregroundStyle)
            .frame(width: KraxlerDesign.controlSize, height: KraxlerDesign.controlSize)
            .contentShape(Circle())
            .kraxlerGlassSurface(
                cornerRadius: KraxlerDesign.controlSize / 2,
                interactive: true
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
