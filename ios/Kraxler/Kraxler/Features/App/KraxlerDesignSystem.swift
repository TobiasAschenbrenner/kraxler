import SwiftUI

enum KraxlerDesign {
    static let accent = Color(red: 0.08, green: 0.68, blue: 0.94)
    static let success = Color.green
    static let warning = Color.red
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
        MountainBoltShape()
            .stroke(
                KraxlerDesign.accent,
                style: StrokeStyle(
                    lineWidth: max(2, size * 0.06),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size * 0.58)
            .accessibilityHidden(true)
    }
}

private struct MountainBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.88))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.42))
        path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.60))
        path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.78))
        return path
    }
}

private struct KraxlerTopographicPattern: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let lineColor = colorScheme == .dark
                ? Color.white.opacity(0.055)
                : Color.black.opacity(0.045)

            for index in 0..<13 {
                var path = Path()
                let offset = CGFloat(index) * 68 - 140
                path.move(to: CGPoint(x: -40, y: offset))
                path.addCurve(
                    to: CGPoint(x: size.width + 40, y: offset + 120),
                    control1: CGPoint(x: size.width * 0.25, y: offset + 84),
                    control2: CGPoint(x: size.width * 0.72, y: offset - 34)
                )
                context.stroke(path, with: .color(lineColor), lineWidth: 0.8)
            }

            for index in 0..<7 {
                let inset = CGFloat(index) * 18
                let rect = CGRect(
                    x: size.width * 0.56 + inset,
                    y: size.height * 0.12 + inset,
                    width: max(20, size.width * 0.58 - inset * 2),
                    height: max(20, size.width * 0.42 - inset * 2)
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(lineColor),
                    lineWidth: 0.7
                )
            }
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
            .regular.interactive(interactive),
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background(
                Color(.secondarySystemBackground).opacity(
                    configuration.isPressed ? 0.72 : 0.96
                ),
                in: RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KraxlerDesign.compactRadius)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
